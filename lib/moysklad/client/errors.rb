class Moysklad::Client
  class Errors
    def self.build res
      Moysklad.logger.warn "Moyskad::Client: #{res.status}: #{res.env.url.to_s}\n#{res.body}"

      case res.status
      when 401 
        raise UnauthorizedError.new res
      when 403
        raise ResourceForbidden.new res
      when 404 
        raise NoResourceFound.new res.body
      when 405
        raise MethodNotAllowedError.new res
      when 500
        raise InternalServerError.new res
      when 502
        raise BadGatewayError.new res
      else 
        raise ParsedError.new res
      end
    end
  end
end

class Moysklad::Client
  class Error < StandardError
    attr_reader :message

    def initialize mess
      @message = mess
    end

    def to_s
      message
    end
  end

  class NoResourceFound < Error; end

  class HtmlParsedError < Error
    def initialize res
      @result  = res
      @message = "[#{res.status}] #{parse_title res.body}"
    end

    private

    def parse_title body
      doc = Nokogiri::HTML body
      # у ResourceForbidden есть <u>
      # у wrong_password <u> несколько
      # Можно ошибку разбирать более грамотно по свойствам type, message, description: http://i.gyazo.com/e9d5d08bd610882d87f39d9002cdf25a.png
      [doc.css('body').css('h1').text,doc.css('body').css('u').to_a.map(&:text).compact.last].join('; ')
    rescue => err
      Moysklad.logger.debug "Moyskad::Client parse error #{err}: #{body}"
      body.force_encoding('utf-8')
    end
  end

  class MethodNotAllowedError < HtmlParsedError
  end

  class UnauthorizedError < HtmlParsedError
  end

  class ResourceForbidden < HtmlParsedError
  end

  class ParsedError < Error
    def initialize result
      @status = result.status
      @result = result
      case result.headers['content-type']
        
      when /application\/xml/
        @error = Moysklad::Entities::Error.parse result.body
        @message = @error.message
      when /text\/html/
        doc = Nokogiri::HTML body
        @message = doc.css('body').css('h1').text
      else
        raise "Unknown content-type #{result.headers['content-type']} to parse error #{result.body}"
      end
    rescue => err
      @message = "error in init #{err}: #{result.body}"
    end

    attr_reader :error
  end


  class BadGatewayError < HtmlParsedError; end
  class InternalServerError < ParsedError; end
end
