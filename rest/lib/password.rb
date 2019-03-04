require "open3"

require_relative './external_login'

module Puavo
  def self.change_passwd(mode, host, actor_dn, actor_username, actor_password,
                         target_user_username, target_user_password)

    started = Time.now

    upstream_res = nil

    if mode != :no_upstream then
      upstream_res = change_passwd_upstream(host, actor_username,
                       actor_password, target_user_username,
                       target_user_password)
      upstream_res[:duration] = (Time.now.to_f - started.to_f).round(5)

      return upstream_res if mode == :upstream_only

      # Return if upstream password change failed.  This allows external
      # (upstream) password service to block password changes, for example
      # because password policy rejects the password or user does not have
      # sufficient permissions for the change operation.
      # Missing user can be normal, in that case we can still try to change
      # the Puavo-password (for users that exist in Puavo but not in external
      # login service).
      if upstream_res[:exit_status] != 0 then
        if (upstream_res[:extlogin_status] \
              != PuavoRest::ExternalLoginStatus::USERMISSING) then
          return upstream_res
        else
          upstream_res[:extlogin_status] \
            = PuavoRest::ExternalLoginStatus::NOCHANGE
        end
      end
    end

    begin
      if !actor_dn then
        actor_dn = PuavoRest::User.by_username!(actor_username).dn.to_s
      end

      res = change_passwd_no_upstream(host, actor_dn, actor_password,
              target_user_username, target_user_password)
      res[:extlogin_status] = upstream_res[:extlogin_status] if upstream_res

    rescue StandardError => e
      short_errmsg = 'failed to change the Puavo password'
      long_errmsg  = 'failed to change the Puavo password for user' \
                       + " '#{ target_user_username }'" \
                       + " by '#{ actor_dn || actor_username }': #{ e.message }"
      $rest_flog.error(short_errmsg, long_errmsg)
      res = {
        :exit_status     => 1,
        :stderr          => e.message,
        :stdout          => '',
      }
      res[:extlogin_status] = upstream_res[:extlogin_status] if upstream_res
    end

    res[:duration] = (Time.now.to_f - started.to_f).round(5)

    return res
  end

  def self.get_external_pw_mgmt_params(user)
    external_pw_mgmt_conf = CONFIG['external_pw_mgmt']
    return nil unless external_pw_mgmt_conf

    org = LdapModel.organisation
    return nil unless org && org.domain.kind_of?(String)

    organisation_name = org.domain.split('.')[0]
    return nil unless organisation_name

    org_specific_conf = external_pw_mgmt_conf[ organisation_name ]
    return nil unless org_specific_conf \
                        && org_specific_conf['url'].kind_of?(String)

    url = org_specific_conf['url']
    schools = org_specific_conf['schools'] || nil

    return [url, schools] unless org_specific_conf['role']
    role_with_password_management = org_specific_conf['role']

    return [url, schools] if user.roles.include?(role_with_password_management)

    return nil
  end

  def self.change_passwd_no_upstream(host, actor_dn,
        actor_password, target_user_username, target_user_password)

    target_user = PuavoRest::User.by_username!(target_user_username)
    target_user_dn = target_user.dn.to_s

    # It would be nice if we could use 'ldappasswd -n' to check if we can
    # change password before doing downstream password change, and then
    # doing the downstream password change first, but unfortunately that
    # does not always work :-(

    res = LdapPassword.change_ldap_passwd(host, actor_dn, actor_password,
                                          target_user_dn, target_user_password)
    return res if res[:exit_status] != 0

    external_pw_mgmt_url, schools = self.get_external_pw_mgmt_params(target_user)
    if external_pw_mgmt_url then
      begin
        target_user_school = target_user.primary_school_id.to_i

        begin
          pri_school = PuavoRest::School.by_id(target_user_school)
        rescue
          pri_school = nil
        end

        if pri_school && pri_school.name == 'Administration'
          # Never sync administration school passwords. They're special cases.
          # WARNING: Hardcoded school name!

          msg = 'not syncing password, this user is in the Administration school'
          $rest_flog.error(msg, msg)

          return {
            :exit_status => 0,
            :stderr      => "",
            :stdout      => "Not syncing passwords for users in the Administration school",
          }
        end

        if schools then
          # A list of schools has been specified...
          unless schools.include?(target_user_school) then
            # ...and this school is not configured for password synchronisation
            return {
              :exit_status => 0,
              :stderr      => "",
              :stdout      => "This school is not configured for password synchronisation, nothing was done",
            }
          end
        end

        change_passwd_downstream(target_user.id,
                                 target_user_username,
                                 target_user_password,
                                 external_pw_mgmt_url)
      rescue StandardError => e
        raise "Cannot change downstream passwords: #{ e.message }"

        # Try resetting password if we can in case downstream password change
        # failed.
        if actor_dn == target_user_dn then
          LdapPassword.change_ldap_passwd(host, actor_dn, target_user_password,
                                          target_user_dn, actor_password)
        end
      end
    end

    return res
  end

  def self.change_passwd_downstream(user_puavo_id, target_user_username,
        target_user_password, external_pw_mgmt_url)

    params = {
      'username'          => target_user_username,
      'user_puavoid'      => user_puavo_id,
      'new_user_password' => target_user_password,
    }

    http_res = HTTP.send('post', external_pw_mgmt_url, :json => params)

    return true if http_res.code == 200

    # If the user does not exist, just keep going
    if http_res.code == 404
      short_msg = 'received a 404 response from the password changing server'
      long_msg = "received a 404 response from the password changing server, assuming the user does not exist, proceeding without password synchronisation"
      $rest_flog.warn(short_msg, long_msg)
      $rest_flog.warn(http_res.body.to_s, http_res.body.to_s)
      return true
    end

    raise http_res.body.to_s
  end

  def self.change_passwd_upstream(host, actor_username, actor_password,
                                  target_user_username, target_user_password)
    begin
      raise 'actor_username not set' \
        unless actor_username.kind_of?(String) && !actor_username.empty?

      external_login = PuavoRest::ExternalLogin.new
      login_service = external_login.new_external_service_handler()
      login_service.change_password(actor_username,
                                    actor_password,
                                    target_user_username,
                                    target_user_password)
    rescue ExternalLoginNotConfigured => e
      # If external logins are not configured we should end up here,
      # and that is normal.
      short_msg = 'not changing upstream password,' \
                    + ' because external logins are not configured'
      long_msg = "#{ short_msg }: #{ e.message }"
      $rest_flog.info(short_msg, long_msg)
      return {
        :exit_status     => 0,
        :extlogin_status => PuavoRest::ExternalLoginStatus::NOTCONFIGURED,
        :stderr          => '',
        :stdout          => long_msg,
      }

    rescue ExternalLoginUserMissing => e
      short_msg = 'not changing upstream password,' \
                    + " target user '#{ target_user_username }' is missing" \
                    + ' from the external service'
      long_msg = "#{ short_msg }: #{ e.message }"
      $rest_flog.info(short_msg, long_msg)
      return {
        :exit_status     => 1,
        :extlogin_status => PuavoRest::ExternalLoginStatus::USERMISSING,
        :stderr          => long_msg,
        :stdout          => '',
      }

    rescue ExternalLoginWrongCredentials => e
      short_errmsg = 'login to upstream password change service failed'
      long_errmsg  = "#{ short_errmsg } for user"         \
                       + " '#{ target_user_username }': " \
                       + e.message
      $rest_flog.error(short_errmsg, long_errmsg)
      return {
        :exit_status     => 1,
        :extlogin_status => PuavoRest::ExternalLoginStatus::BADUSERCREDS,
        :stderr          => long_errmsg,
        :stdout          => '',
      }

    rescue StandardError => e
      short_errmsg = 'changing upstream password failed'
      long_errmsg  = "#{ short_errmsg } for user"         \
                       + " '#{ target_user_username }': " \
                       + e.message
      $rest_flog.error(short_errmsg, long_errmsg)
      return {
        :exit_status     => 1,
        :extlogin_status => PuavoRest::ExternalLoginStatus::UPDATEERROR,
        :stderr          => long_errmsg,
        :stdout          => '',
      }
    end

    $rest_flog.info('upstream password changed',
                    'upstream password changed for user' \
                      + " '#{ target_user_username }' by '#{ actor_username }'")

    return {
      :exit_status     => 0,
      :extlogin_status => PuavoRest::ExternalLoginStatus::UPDATED,
      :stderr          => '',
      :stdout          => 'password change to external login service ok',
    }
  end

  class LdapPassword
    def self.change_ldap_passwd(host, bind_dn, bind_dn_pw, user_dn, new_pw)
      cmd = [ 'ldappasswd',
              # use simple authentication instead of SASL
              '-x',
              # issue StartTLS (Transport Layer Security) extended operation
              '-Z',
              # specify an alternate host on which the ldap server is running
              '-h', host,
              # Distinguished Name used to bind to the LDAP directory
              '-D', bind_dn,
              # the password to bind with
              '-w', bind_dn_pw,
              # set the new password
              '-s', new_pw,
              # timeout after 20 sec
              '-o', 'nettimeout=20',
              # The user whose password we're changing
              user_dn.to_s ]

      stdout_str, stderr_str, status = Open3.capture3(*cmd)

      return {
        :exit_status => status.exitstatus,
        :stderr      => stderr_str,
        :stdout      => stdout_str,
      }
    end
  end
end
