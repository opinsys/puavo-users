require "sinatra/r18n"

module PuavoRest

class Password < PuavoSinatra
  register Sinatra::R18n

  post "/password/send_token" do
    auth :pw_mgmt_server_auth

    # FIXME Request limit? Denial of Service?

    user = User.by_username(params["username"])

    if user.nil?
      status 404
      return json({ :status => "failed",
                    :error => "Cannot find user" })
    end

    if user.email.nil?
      status 404
      return json({ :status => "failed",
                    :error => "User does not have an email address" })
    end

    jwt_data = {
      # Issued At
      "iat" => Time.now.to_i,

      "username" => user.username,
      "organisation_domain" => user.organisation_domain
    }

    jwt = JWT.encode(jwt_data, CONFIG["password_management"]["secret"])

    @password_reset_url = "https://#{ user.organisation_domain }/users/password/#{ jwt }/reset"
    @first_name = user.first_name
    @username = user.username

    emails = Array(user.email)
    emails += user.secondary_emails if user.secondary_emails
    message = erb(:password_email, :layout => false)

    emails.each do |email|
      $mailer.send( :to => email,
                    :subject => t.password_management.subject,
                    :body => message )
    end

    json({ :status => 'successfully' })

  end

  put "/password/change/:jwt" do
    auth :pw_mgmt_server_auth

    if json_params["new_password"].nil? || json_params["new_password"].empty?
      status 404
      return json({ :status => "failed",
                    :error  => "Invalid new password" })
    end

    begin
      jwt_decode_data = JWT.decode(params[:jwt],
                                   CONFIG["password_management"]["secret"])
      jwt_data = jwt_decode_data[0] # jwt_decode_data is [payload, header]
    rescue JWT::DecodeError
      status 404
      return json({ :status => "failed",
                    :error => "Invalid jwt token" })
    end

    lifetime =  CONFIG["password_management"]["lifetime"]
    if Time.at( jwt_data["iat"] + lifetime ) < Time.now
      status 404
      return json({ :status => "failed",
                    :error => "Token lifetime has expired" })
    end

    if jwt_data["organisation_domain"] != request.host
      status 404
      return json({ :status => "failed",
                    :error => "Invalid organisation domain" })

    end

    user = User.by_username(jwt_data["username"])
    if user.nil? then
      status 404
      return json({ :status => "failed",
                    :error => "Cannot find user" })
    end

    res = Puavo.change_passwd(:no_upstream,
                              CONFIG['ldap'],
                              PUAVO_ETC.ds_pw_mgmt_dn,
                              nil,
                              PUAVO_ETC.ds_pw_mgmt_password,
                              user.username,
                              json_params['new_password'],
                              '???')    # no request ID

    flog.info("changed user password for '#{ user.username }' (DN #{user.dn.to_s})")

    if res[:exit_status] != 0
      status 404
      return json({ :status => "failed",
                    :error => "Cannot change password for user: #{ user.username }" })
    end

    @first_name = user.first_name

    emails = Array(user.email)
    emails += user.secondary_emails if user.secondary_emails
    message = erb(:password_has_been_reset, :layout => false)

    emails.each do |email|
      $mailer.send( :to => email,
                    :subject => t.password_management.subject,
                    :body => message )
    end

    json({ :status => 'successfully' })
  end

end
end

