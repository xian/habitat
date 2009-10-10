module Habitat
  class RspecExampleGroup < defined?(Merb) ? Merb::Test::ExampleGroup : Spec::Example::ExampleGroup
    cattr_accessor :free_browsers, :selenium_browser_creation_mutex, :browser_number
    self.free_browsers = []
    self.selenium_browser_creation_mutex = Mutex.new
    self.browser_number = 0

    attr_accessor :browsers
    attr_accessor :allocated_browsers

    before(:all) do
    end

    before(:each) do
      self.browsers = {}
      self.allocated_browsers = []
    end

    after(:each) do
      #unless example_passed?
      #  basedir = ENV['CC_BUILD_ARTIFACTS'] || "/tmp"
      #  screenshot_name = "#{basedir}/selenium-screenshot-#{__full_description.gsub("/", "_")}.jpg"
      #  allocated_browsers.first.driver.capture_screenshot(screenshot_name)
      #end

      threads = allocated_browsers.map do |browser|
        Thread.new do
          browser.reset
        end
      end
      join_all(threads)
      allocated_browsers.each do |browser|
        # N.B. Unshifting to preserve order
        self.class.free_browsers.unshift browser
      end

      at_exit do
        self.free_browsers.each(&:close)
        self.free_browsers = []
      end
    end

    def method_which_must_exist_to_make_testing_this_spec_work
    end

    def as(*actors, &block)
      actors.each do |actor|
        browser = browsers[actor] ||= begin
          browser = allocate_browser
          allocated_browsers << browser
          browser.actor_name = actor
          browser
        end
        begin
          browser.run(&block)
        rescue ::Exception => exception
          exception.message.replace("As #{actor}: #{exception.message}")
          raise exception
        end
      end
    end

    def concurrently(&block)
      concurrent_action_collector = ConcurrentActionCollector.new(self)
      concurrent_action_collector.instance_eval(&block)
      concurrent_action_collector.run
    end

    def concurrently_as(*actors, &block)
      concurrently do
        as(*actors, &block)
      end
    end

    class ConcurrentActionCollector
      attr_reader :spec, :concurrent_procs

      def initialize(spec)
        @spec = spec
        @concurrent_procs = []
      end

      def as(*actors, &block)
        actors.each do |actor|
          add_concurrent_proc(actor, &block)
        end
      end

      def add_concurrent_proc(actor, &block)
        concurrent_procs << lambda { spec.as(actor, &block) }
      end

      def run
        threads = concurrent_procs.map do |proc|
          Thread.new do
            begin
              proc.call
            rescue Exception => e
              puts "---- CAUGHT EXCEPTION IN ConcurrentActionCollector#run --------------------------------"
              puts e.message
              puts e.backtrace * "\n"
              raise e
            end
          end
        end
        spec.join_all(threads)
      end
    end

    def join_all(threads)
      exceptions = []
      threads.each do |thread|
        begin
          thread.join
        rescue Exception => e
          exceptions << e
        end
      end
      p "There were multiple exceptions, just throwing the first one..." if exceptions.size > 1
      raise exceptions.first unless exceptions.empty?
    end

    def allocate_browser
      return self.class.free_browsers.pop unless self.class.free_browsers.empty?
      driver = nil

      # Selenium RC server appears to have a thread safety issue when opening Firefox browsers...
      self.class.selenium_browser_creation_mutex.synchronize do
        driver = Webrat::SeleniumSession.new
      end
      #driver.prepare_nifty_display_stuff self.browser_number
      #driver.set_polonium_status "Preparing browser..."

      self.browser_number += 1

      Habitat::Browser.new(driver, self, "/commercial/login", Click::Commercial::LoginPage)
    end

  end
end