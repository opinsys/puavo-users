class JSONError < Exception

  # @param [String, Hash] error message
  # @option message :user Error message that is displayed to requesting user
  # @option message :mgs Internal error message for stack traces
  def initialize(message)
    if message.class == String
      super(message)
    else
      @user_message = message[:user]
      super(message[:msg] || message[:user])
    end
  end

  def to_json
    @error.to_json
  end

  def http_code
    500
  end

  def headers
   {"Content-Type" => "application/json"}
  end

  def as_json
    res = {
      :error => {
        :code => self.class.name.split(":").last
      }
    }
    if @user_message
      res[:error][:message] = @user_message
    end
    res
  end

  def to_json
    as_json.to_json
  end

end

class NotFound < JSONError
  def http_code
    404
  end
end

class BadInput < JSONError
  def http_code
    400
  end
end

class BadCredentials < JSONError
  def http_code
    401
  end
end

class KerberosError < JSONError
  def http_code
    401
  end
end

class InternalError < JSONError
  def http_code
    500
  end
end

class Unauthorized < JSONError
  def http_code
    401
  end

  def headers
    super.merge "WWW-Authenticate" => "Negotiate"
  end
end
