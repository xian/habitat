module Habitat
  class Browser
    attr_reader :driver
    attr_reader :actor_name
    attr_accessor :current_page
    def initialize(driver, spec, initial_url, initial_page)
      @driver   = driver
      self.spec = spec

      @initial_url = initial_url
      @initial_page = initial_page

      driver.visit initial_url
      switch_to initial_page
    end

    def run(&block)
      instance_eval(&block)
    end

    def actor_name=(name)
      @actor_name = name
    end

    def reset
      #driver.set_polonium_status("Test has concluded, resetting browser...")
      @actor_name = nil
      #driver.logout
      driver.visit @initial_url
      switch_to @initial_page
    end

    def close
      driver.selenium.stop
    end

    def switch_to(page)
      page = page.new if page.instance_of? Class

      self.current_page = page
      page.prepare(self)
    end

    def with(element, &block)
      element = element.new if element.instance_of? Class

      self.element_with_focus = element
      element.prepare(self)

      instance_eval &block
    ensure
      self.element_with_focus = nil
    end

    def respond_to?(method)
      current_page.respond_to?(method)
    end

    def method_missing(method, *args, &block)
      if element_with_focus && element_with_focus.respond_to?(method)
        element_with_focus.__send__(method, *args, &block)
      elsif current_page.respond_to?(method)
        # todo: js and html escape as needed below
        #driver.set_polonium_status(<<-STATUS)
        #  <b>Spec:</b>
        #  <div style="margin-left:10px">#{spec.__full_description}</div>
        #  <b>As #{actor_name}:</b>
        #  <div style="margin-left:10px">#{method} #{args}</div>
        #STATUS

        current_page.__send__(method, *args, &block)
      else
        spec.__send__(method, *args, &block)
      end
    end

    private
      attr_accessor :spec, :element_with_focus
  end
end