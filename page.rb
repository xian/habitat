module Habitat

  class Preparable

    attr_reader :browser

    def prepare(browser)
      @browser = browser

      wait_until_ready
    end

    def wait_until_ready
      # Implement in subclasses. Does nothing by default.
    end

    def method_missing(method, *args, &block)
      if browser.driver.respond_to?(method)
        browser.driver.__send__(method, *args, &block)
      else
        super
      end
    end

    def current_dom
      Nokogiri::HTML.parse(selenium.get_html_source)
    end

  end

  class Widget < Preparable

  end

  class Page < Preparable

    def switch_to(*args, &block)
      browser.switch_to(*args, &block)
    end

    def type(*args, &block)
      browser.driver.type(*args, &block)
    end

    def eval_js(js)
      get_eval(<<-JS)
        (function() {
          with(this) {
            #{js}
          }
        }).call(#{current_window_js});
      JS
    end

  end

end