require 'http'

module PuavoRest

  class Certs < PuavoSinatra

    # Deprecated, but should be supported for a long time
    # for all Ubuntu Trusty / Debian Stretch versions of puavo-os.
    post "/v3/hosts/certs/sign" do
      auth :basic_auth

      host = Host.by_dn(User.current.dn)
      unless host then
        status 404
        return json({ 'error' => 'could not find the connecting host' })
      end

      org = Host.organisation
      org_key = org.domain.split("." + PUAVO_ETC.topdomain).first

      fqdn = host.hostname + "." + org.domain

      res = HTTP.basic_auth(:user => LdapModel.settings[:credentials][:dn],
                            :pass => LdapModel.settings[:credentials][:password])
        .delete(CONFIG["puavo_ca"] + "/certificates/revoke.json",
                :json => { "fqdn" => fqdn } )

      if res.code != 200 && res.code != 404
        raise InternalError, "Unable to revoke certificate"
      end

      res = HTTP.basic_auth(:user => LdapModel.settings[:credentials][:dn],
                            :pass => LdapModel.settings[:credentials][:password])
        .post(CONFIG["puavo_ca"] + "/certificates.json",
              :json => {
                "org" => org_key,
                "certificate" => {
                  "fqdn" => fqdn,
                  "host_certificate_request" => json_params["certificate_request"] } } )

      if !res.code.to_s.match(/^2/)
        raise InternalError, "Unable to sign certificate"
      end

      json res.parse["certificate"]
    end

  end
end
