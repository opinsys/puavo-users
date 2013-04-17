class School < LdapBase
  ldap_mapping( :dn_attribute => PUAVO_CONFIG['school']['dn_attribute'],
                :prefix => PUAVO_CONFIG['school']['prefix'],
                :classes => PUAVO_CONFIG['school']['classes'] )

  def method_missing(*args)
    begin
      super
    rescue
      if PUAVO_CONFIG['school']['attributes'][args.first.to_s]
        self.send(PUAVO_CONFIG['school']['attributes'][args.first.to_s])
      else
        super
      end
    end
  end
  def id
    self.puavoId.to_s unless self.puavoId.nil?
  end

  def self.all_with_permissions(user)
    if user.organisation_owner?
      # FIXME sort
      self.all
    else
      # FIXME sort
      self.find(:all, :attribute => "puavoSchoolAdmin", :value => user.dn)
    end
  end
end

