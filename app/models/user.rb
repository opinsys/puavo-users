# -*- coding: utf-8 -*-
class User < LdapBase
  # When using user mass import we have to store uids which are already been taken. See validate method.
  @@reserved_uids = Array.new

  include Puavo::AuthenticationMixin
  include Puavo::Locale
  include Puavo::Helpers

  ldap_mapping( :dn_attribute => "puavoId",
                :prefix => "ou=People",
                :classes => ['top', 'posixAccount', 'inetOrgPerson', 'puavoEduPerson','sambaSamAccount','eduPerson'] )
  belongs_to :groups, :class_name => 'Group', :many => 'member', :primary_key => "dn"
  belongs_to :uidGroups, :class_name => 'Group', :many => 'memberUid', :primary_key => "Uid"
  belongs_to( :primary_group, :class_name => 'School',
              :foreign_key => 'gidNumber',
              :primary_key => 'gidNumber' )
  belongs_to( :school, :class_name => 'School',
              :foreign_key => 'puavoSchool',
              :primary_key => 'dn' )
  belongs_to :member_school, :class_name => 'School', :many => 'member', :primary_key => "dn"
  belongs_to :member_uid_school, :class_name => 'School', :many => 'memberUid', :primary_key => "uid"
  belongs_to :roles, :class_name => 'Role', :many => 'member', :primary_key => "dn"
  belongs_to :uidRoles, :class_name => 'Role', :many => 'memberUid', :primary_key => "uid"

  before_validation :set_special_ldap_value

  before_save :is_uid_changed, :set_preferred_language

  before_update :change_password

  after_save :set_school_admin
  after_save :add_member_uid_to_models
  after_save :update_roles

  before_destroy :delete_all_associations, :delete_kerberos_principal

  after_create :change_password_no_upstream

  validate :validate

  alias_method :v1_as_json, :as_json

  # Attributes from relations and other helpers
  @@extra_attributes = [
     :password,
     :new_password,
     :school_admin,
     :uid_has_changed,
     :role_ids,
     :role_name,
     :mass_import,
     :image,
     :earlier_user,
     :new_password_confirmation,
     :password_change_mode
  ]

  # role_ids/role_name: see set_role_ids_by_role_name and validate methods
  attr_accessor(*@@extra_attributes)

  cattr_accessor :reserved_uids

  OVERWRITE_CHARACTERS = {
    "Ä" => "a",
    "ä" => "a",
    "Ö" => "o",
    "ö" => "o",
    "Å" => "a",
    "å" => "a",
    "é" => "e"
  }


  def self.image_size
    { :width => 120, :height => 160 }
  end

  def as_json(*args)
    self.class.build_hash_for_to_json(self)
  end

  # Building hash for as_json method with better name of attributes
  #  * data argument may be User or Hash
  def self.build_hash_for_to_json(data)
    new_user_hash = {}
    # Note: value of attribute may be raw ldap value eg. { givenName => ["Joe"] }
    user_attributes =
      [ { :original_attribute_name => "givenName",
          :new_attribute_name => "given_name",
          :value_block => lambda{ |value| Array(value).first } },
        { :original_attribute_name => "puavoAdminOfSchool",
          :new_attribute_name => "admin_of_schools",
          :value_block => lambda{ |value| value ? Array(value).map{ |s| s.to_s.match(/puavoId=([^, ]+)/)[1].to_i } : [] } },
        { :original_attribute_name => "puavoSchool",
          :new_attribute_name => "school_id",
          :value_block => lambda{ |value| value.to_s.match(/puavoId=([^, ]+)/)[1].to_i } },
        { :original_attribute_name => "telephoneNumber",
          :new_attribute_name => "telephone_number",
          :value_block => lambda{ |value| Array(value).first } },
        { :original_attribute_name => "displayName",
          :new_attribute_name => "name",
          :value_block => lambda{ |value| Array(value).first } },
        { :original_attribute_name => "gidNumber",
          :new_attribute_name => "gid",
          :value_block => lambda{ |value| Array(value).first.to_i } },
        { :original_attribute_name => "homeDirectory",
          :new_attribute_name => "home_directory",
          :value_block => lambda{ |value| Array(value).first } },
        { :original_attribute_name => "puavoEduPersonAffiliation",
          :new_attribute_name => "user_type",
          :value_block => lambda{ |value| Array(value).first } },
        { :original_attribute_name => "mail",
          :new_attribute_name => "email",
          :value_block => lambda{ |value| Array(value).first } },
        { :original_attribute_name => "puavoEduPersonReverseDisplayName",
          :new_attribute_name => "reverse_name",
          :value_block => lambda{ |value| Array(value).first } },
        { :original_attribute_name => "sn",
          :new_attribute_name => "surname",
          :value_block => lambda{ |value| Array(value).first } },
        { :original_attribute_name => "uid",
          :new_attribute_name => "uid",
          :value_block => lambda{ |value| Array(value).first } },
        { :original_attribute_name => "puavoId",
          :new_attribute_name => "puavo_id",
          :value_block => lambda{ |value| Array(value).first.to_i } },
        { :original_attribute_name => "sambaSID",
          :new_attribute_name => "samba_sid",
          :value_block => lambda{ |value| Array(value).first } },
        { :original_attribute_name => "uidNumber",
          :new_attribute_name => "uid_number",
          :value_block => lambda{ |value| Array(value).first.to_i } },
        { :original_attribute_name => "loginShell",
          :new_attribute_name => "login_shell",
          :value_block => lambda{ |value| Array(value).first } },
        { :original_attribute_name => "sambaPrimaryGroupSID",
          :new_attribute_name => "samba_primary_group_SID",
          :value_block => lambda{ |value| Array(value).first } } ]

    user_attributes.each do |attr|
      attribute_value = data.class == Hash ? data[attr[:original_attribute_name]] : data.send(attr[:original_attribute_name])
      new_user_hash[attr[:new_attribute_name]] = attr[:value_block].call(attribute_value)
    end
    return new_user_hash
  end

  def all_attributes
    attrs = attributes
    @@extra_attributes.each do |attr|
      attrs[attr.to_s] = send(attr)
    end
    attrs
  end

  def validate
    # givenName validation
    if self.givenName.empty?
      errors.add( :givenName, I18n.t("activeldap.errors.messages.blank",
                                    :attribute => I18n.t("activeldap.attributes.user.givenName") ) )
    end

    # Uid validation
    #
    # Password confirmation
    if !self.new_password_confirmation.nil? && self.new_password != self.new_password_confirmation
      errors.add( :new_password_confirmation, I18n.t("activeldap.errors.messages.confirmation",
                                        :attribute => I18n.t("activeldap.attributes.user.new_password")) )
    end

    if !self.new_password_confirmation.nil? && !self.new_password_confirmation.empty? then
      case get_organisation_password_requirements
        when 'Google'
          if self.new_password.size < 8 then
            errors.add(:new_password, I18n.t("activeldap.errors.messages.gsuite_password_too_short"))
          elsif self.new_password[0] == ' ' || self.new_password[-1] == ' ' then
            errors.add(:new_password, I18n.t("activeldap.errors.messages.gsuite_password_whitespace"))
          elsif !self.new_password.ascii_only? then
            errors.add(:new_password, I18n.t("activeldap.errors.messages.gsuite_password_ascii_only"))
          end
        when 'oulu_ad'
          if self.new_password.size < 8 then
            errors.add(:new_password, I18n.t("activeldap.errors.messages.oulu_ad_password_too_short"))
          end
        when 'SixCharsMin'
          if self.new_password.size < 6 then
            errors.add(:new_password, I18n.t("activeldap.errors.messages.sixcharsmin_password_too_short"))
          end
        when 'SevenCharsMin'
          if self.new_password.size < 7 then
            errors.add(:new_password, I18n.t("activeldap.errors.messages.sevencharsmin_password_too_short"))
          end
      end
    end

    # Validates length of uid
    if self.uid.to_s.size < 3
      errors.add( :uid,  I18n.t("activeldap.errors.messages.too_short",
                                :attribute => I18n.t("activeldap.attributes.user.uid"),
                                :count => 3) )
    end
    if self.uid.to_s.size > 255
      errors.add( :uid, I18n.t("activeldap.errors.messages.too_long",
                               :attribute => I18n.t("activeldap.attributes.user.uid"),
                               :count => 255) )
    end
    # Format of uid, default configuration:
    #   * allowed characters is a-z0-9.-
    #   * uid must begin with the small letter
    allow_uppercase_characters_uid = Puavo::Organisation.
      find(LdapOrganisation.current.cn).
      value_by_key("allow_uppercase_characters_uid").
      to_s.chomp == "true" ? true : false rescue false

    usernameFailed = false

    unless self.uid.to_s =~ ( allow_uppercase_characters_uid ? /^[a-zA-Z]/ : /^[a-z]/ )
      errors.add( :uid, I18n.t("activeldap.errors.messages.user.must_begin_with") )
      usernameFailed = true
    end

    unless self.uid.to_s =~ ( allow_uppercase_characters_uid ? /^[a-zA-Z0-9.-]+$/ : /^[a-z0-9.-]+$/ )
      errors.add( :uid, I18n.t("activeldap.errors.messages.user.invalid_characters") )
      usernameFailed = true
    end

    # Role validation
    #
    # The user must have at least one role
    #
    # Set role_ids value by role_name. If get false role_name is invalid.
    unless new_group_management?(self.school)
      if set_role_ids_by_role_name(role_name) == false
        errors.add( :role_name,
                    I18n.t("activeldap.errors.messages.invalid",
                           :attribute => I18n.t("activeldap.attributes.user.role_name") ) )
        # If role_ids is nil: user's role associations not change when save object. Then roles must not be empty!
        # If role_ids is not nil: user's roles value will change when save object. Then role_ids must not be empty!
      elsif (!role_ids.nil? && role_ids.empty?) || ( role_ids.nil? && roles.empty? )
        errors.add :role_ids, I18n.t("activeldap.errors.messages.blank",
                                     :attribute => I18n.t("activeldap.attributes.user.roles") )
      else
        # Role must be found by id!
        unless role_ids.nil?
          role_ids.each do |id|
            if Role.find(:first, id).nil?
              errors.add :role_ids, I18n.t("activeldap.errors.messages.blank",
                                           :attribute => I18n.t("activeldap.attributes.user.role_ids") )
            end
          end
        end
      end
    end

    locale_puavoEduPersonAffiliation_name = I18n.t("activeldap.attributes.user.puavoEduPersonAffiliationDeprecated")
    if new_group_management?(self.school)
      locale_puavoEduPersonAffiliation_name = I18n.t("activeldap.attributes.user.puavoEduPersonAffiliation")
    end

    if self.puavoEduPersonAffiliation.nil?
      errors.add( :puavoEduPersonAffiliation, I18n.t("activeldap.errors.messages.blank",
                                                     :attribute => locale_puavoEduPersonAffiliation_name ) )
    end

    # puavoEduPersonAffiliation validation
    Array(self.puavoEduPersonAffiliation).each do |value|
      unless self.class.puavoEduPersonAffiliation_list.include?(value)
        errors.add( :puavoEduPersonAffiliation,
                    I18n.t("activeldap.errors.messages.invalid",
                           :attribute => locale_puavoEduPersonAffiliation_name ) )
      end
    end

    # Validate the image, if set. Must be done here, because if the file is not a valid image file,
    # it will cause an exception in ImageMagick.
    if self.image && !self.image.path.to_s.empty?
      begin
        resize_image
      rescue
        errors.add(:image, I18n.t('activeldap.errors.messages.image_failed'))
      end
    end

    # If the username failed validation, stop here. Older versions if the LDAP library allowed invalid characters
    # in the username and the user was returned to the form, but in newer versions the LDAP query fails. So force
    # stop here if the username isn't valid.
    return false if usernameFailed

    # Validate uid uniqueness only if there are no other errors in the uid
    if !self.uid.nil? && !self.uid.empty? && errors.select{ |k,v| k == "uid" }.empty?
      if user = User.find(:first, :attribute => "uid", :value => self.uid)
        if user.puavoId != self.puavoId
          self.earlier_user = user
          errors.add :uid, I18n.t("activeldap.errors.messages.taken",
                                  :attribute => I18n.t("activeldap.attributes.user.uid") )
        end
      end
    end

    # Unique validation for puavoExternalId
    if !self.puavoExternalId.nil? && !self.puavoExternalId.empty?
      if user = User.find(:first, :attribute => "puavoExternalId", :value => self.puavoExternalId)
        if user.puavoId != self.puavoId
          errors.add :puavoExternalId, I18n.t("activeldap.errors.messages.taken",
                                              :attribute => I18n.t("activeldap.attributes.user.puavoExternalId") )
        end
      end
    end

    # mass import uid validation
    if self.mass_import
      if @@reserved_uids.include?(self.uid)
        errors.add :uid, I18n.t("activeldap.errors.messages.taken",
                                :attribute => I18n.t("activeldap.attributes.user.uid") )
      end
    end

    emailFailed = false

    if !self.mail.nil? && !self.mail.empty?
      Array(self.mail).each do |m|
        m.strip!

        # There are (supposedly) checks that validate email addresses... but they don't
        # seem to work. So... just brute-force it.
        # Regex taken from https://www.regular-expressions.info/email.html
        if !m.empty? && !/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.match(m)
          emailFailed = true
        end
      end

      if emailFailed
        errors.add(:mail, I18n.t('activeldap.errors.messages.email_not_valid'))
        return false
      end

      email_dup = User.find(:first, :attribute => "mail", :value => self.mail)
      if email_dup && email_dup.puavoId != self.puavoId
        errors.add(
          :mail,
          I18n.t(
            "activeldap.errors.messages.taken",
            :attribute => I18n.t("activeldap.attributes.user.mail")
          )
        )
      end
    end
  end

  def change_password_no_upstream
    change_password(:no_upstream)
  end

  def change_password(mode=nil)
    return if new_password.nil? || new_password.empty?

    ldap_conf = User.configuration

    # ldap_conf[:bind_dn] may not be associated with a username in the
    # current organisation in which case it should be nil
    actor_dn = ldap_conf[:bind_dn]
    actor_username = User.find(actor_dn).uid rescue nil

    # use a particular passowrd change mode
    # (:all, :upstream_only, :no_upstream) if requested, otherwise
    # the current operation default or default
    pw_change_mode = password_change_mode || mode || :all

    rest_params = {
                    :actor_dn             => actor_dn,
                    :actor_username       => actor_username,
                    :actor_password       => ldap_conf[:password],
                    :host                 => ldap_conf[:host],
                    :mode                 => pw_change_mode,
                    :target_user_username => self.uid,
                    :target_user_password => new_password,
                  }

    res = rest_proxy.put('/v3/users/password', :params => rest_params).parse
    res = {} unless res.kind_of?(Hash)

    FLOG.info('rest call to PUT /v3/users/password', res.merge(
      :from => 'user model',
      :user => {
        :dn  => self.dn.to_s,
        :uid => self.uid,
      }
    ))

    if res['exit_status'] != 0 then
      logger.warn "rest call to PUT /v3/users/password failed: #{ res.inspect }"

      if res.include?('stderr')
        # This is ugly, but we have to tell the user why the password could not be changed
        # TODO: A better system for this
        raise User::UserError, I18n.t('flash.password.failed_details', :details => res['stderr'])
      else
        raise User::UserError, I18n.t('flash.password.failed')
      end
    end

    return true
  end

  def read_only?
    return false if self.new_entry?

    return false unless users_synch?(self.school)

    (self.puavoExternalId.nil? or self.puavoExternalId.empty?) ? false : true
  end

  def self.import_columns
    columns = ["givenName", "sn", "uid", "new_password"]

    columns.push("role_name")

    columns.push("puavoEduPersonAffiliation")

    return columns
  end

  # FIXME, where is better location on this method? Using same code also on other model?
  def self.human_attribute_name(*args)
    if I18n.t("activeldap.attributes").has_key?(:user) &&
       # Attribute key name
       I18n.t("activeldap.attributes.user").has_key?(args[0].to_sym)

      if args[0] == "puavoEduPersonAffiliation"
        return I18n.t("activeldap.attributes.user.puavoEduPersonAffiliationDeprecated")
      end

      return I18n.t("activeldap.attributes.user.#{args[0]}")
    end
    super(*args)
  end

  #
  # Retruns the array (users).
  #
  # Example of Data: {"0"=>["Wilk", "Mabey"], "1"=>["Ben", "Joseph"], "2"=>["Class 4", "Class 4"]}
  # Example of Columns: {"0" => "Lastname", "1" => "Given names", "2" => "Group" }
  #
  def self.hash_array_data_to_user(data, columns, school)
    users = []
    max_data_column_number = (columns.count - 1).to_s
    # Row contains one user data (row number == user_index)
    0.upto data["0"].length-1 do |user_index|
      next if Array(data[ (max_data_column_number.to_i + 1).to_s ]).include?(user_index.to_s)
      user = Hash.new
      0.upto max_data_column_number.to_i do |column_index|
        unless columns[column_index].nil?
          user[columns[column_index]] = data[column_index.to_s][user_index]
        end
      end
      new_user = User.new(user)
      new_user.puavoSchool = school.dn
      new_user.mass_import = true
      if data[(max_data_column_number.to_i + 1).to_s] && data[(max_data_column_number.to_i + 1).to_s][user_index.to_s]
        new_user.earlier_user = User.find(data[(max_data_column_number.to_i + 1).to_s][user_index.to_s])
      end
      users.push new_user
    end

    return users
  end

  def self.validate_users(users)
    valid = []
    invalid = []
    User.reserved_uids = []

    users.each do |user|
      if  user.uid.nil? or user.uid.empty?
        user.generate_username
      end
      if user.puavoId.nil?
        user.puavoId = "0"
      end
      user.valid? ? (valid.push user) : (invalid.push user)
      User.reserved_uids.push user.uid
    end
    return valid, invalid
  end

  #
  # Return array. This array includes arrays of users, one per role
  #
  def self.list_by_role(users)
    users_by_role = []
    roles_by_name = users.map {|user| user.roles.first.displayName}.uniq
    roles_by_name.each do |role_name|
      users_by_role.push users.select {|u| u.roles.first.displayName == role_name}
    end
    return users_by_role
  end

  def generate_password(size=8)
    characters = (("a".."z").to_a + ("0".."9").to_a).delete_if do |char| not char[/[015iIosql]/].nil? end
    Array.new(size) { characters[rand(characters.size)] }.join
  end

  def set_generated_password
    self.new_password = generate_password
  end

  def set_password(password, salt=nil)
    salt ||= generate_password(5)
    pw = Base64.encode64(Digest::SHA1.digest(password + salt) + salt).chomp!
    self.userPassword = "{SSHA}" + pw
  end

  def self.puavoEduPersonAffiliation_list
    ["teacher", "staff", "student", "visitor", "parent", "admin", "testuser"]
  end

  def destroy(*args)
    delete_dn_cache
    super
  end

  def update_attributes(*args)
    delete_dn_cache
    super
  end

  def id
    self.puavoId.to_s unless self.puavoId.nil?
  end

  def organisation_owner?
    LdapOrganisation.current.owner.include? self.dn
  end

  # Update user's role list by role_ids
  def update_roles
    unless new_group_management?(self.school)
      unless self.role_ids.nil?

        add_roles = self.role_ids
        Role.search_as_utf8( :filter => "(memberUid=#{self.uid})",
                             :scope => :one,
                             :attributes => ["puavoId"] ).each do |role_dn, values|

          if add_roles.include?(values["puavoId"])
            add_roles.delete(values["puavoId"])
          else
            # Delete roles
            Role.ldap_modify_operation(role_dn, :delete, [{ "memberUid" => [self.uid] },
                                                          { "member" => [self.dn.to_s] }])
          end
        end

        # Add roles
        add_roles.each do |role_id|
          Role.ldap_modify_operation("puavoId=#{role_id},#{Role.base.to_s}",
                                     :add, [{ "memberUid" => [self.uid] },
                                            { "member" => [self.dn.to_s] }])
        end

        self.reload
        self.update_associations
      end
    end
  end


  def generate_username
    self.uid = username_escape(self.givenName).to_s + "." + username_escape(self.sn).to_s
  end

  def username_escape(string)
    string.strip.split(//).map do |char|
      OVERWRITE_CHARACTERS.has_key?(char) ? OVERWRITE_CHARACTERS[char] : char
    end.join.downcase.gsub(/[^a-z]/, '')
  end

  # Update User - Group association by roles
  def update_associations
    unless new_group_management?(self.school)
      new_group_list =
        self.roles.inject([]) do |result, role|
        result + role.groups.map{ |g| g.dn.to_s }
      end

      Group.search_as_utf8( :filter => "(memberUid=#{self.uid})",
                            :scope => :one,
                            :attributes => ["puavoId"] ).each do |group_dn, values|

        if new_group_list.include?(group_dn)
          new_group_list.delete(group_dn)
        else
          Group.ldap_modify_operation(group_dn, :delete, [{ "memberUid" => [self.uid]},
                                                          { "member" => [self.dn.to_s] }])
        end
      end

      new_group_list.each do |group_dn|
        Group.ldap_modify_operation(group_dn, :add, [{ "memberUid" => [self.uid]},
                                                     { "member" => [self.dn.to_s] }])
      end
    end
  end

  def human_readable_format(attribute)
    case attribute
    when "role_ids"
      self.send(attribute).map do |id|
        Role.find(id).displayName
      end
    when "puavoEduPersonAffiliation"
      if self.class.puavoEduPersonAffiliation_list.include?(self.send(attribute).to_s)
        I18n.t( 'puavoEduPersonAffiliation_' + self.send(attribute) )
      else
        Array(self.send(attribute)).first.to_s
      end
    when "role_name"
      if self.send(attribute).class == Array
        return self.send(attribute).join(", ")
      end
      self.send(attribute)
    else
      Array(self.send(attribute)).first.to_s
    end
  end

  def change_school(new_school_dn)
    school_dn = self.puavoSchool
    LdapBase.ldap_modify_operation( self.puavoSchool,
                                    :delete, [{ "member" => [self.dn.to_s] }]) rescue Exception
    LdapBase.ldap_modify_operation( self.puavoSchool,
                                    :delete, [{ "memberUid" => [self.uid.to_s] }]) rescue Exception
    self.puavoSchool = new_school_dn
  end

  def managed_schools
    device = Device.find( :all,
                          :attributes => ["*", "+"],
                          :attribute => 'creatorsName',
                          :value => self.dn.to_s).max do |a,b|
      a.puavoId.to_i <=> b.puavoId.to_i
    end
    default_school_dn = device.puavoSchool if device

    if Array(LdapOrganisation.current.owner).include?(self.dn)
      schools = School.all
    else
      schools = School.find( :all,
                             :attribute => 'puavoSchoolAdmin',
                             :value => self.dn )
    end

    if default_school = schools.select{ |s| s.dn.to_s == default_school_dn.to_s }.first
      default_school_id = default_school.puavoId
    else
      default_school_id = schools.first.puavoId
    end

    return ( { 'label' => 'School',
               'default' => default_school_id,
               'title' => 'School selection',
               'question' => 'Select school: ',
               'list' =>  schools.map{ |s| s.v1_as_json }  } ) unless schools.empty?
  end

  def administrative_groups
    return @administrative_groups if @administrative_groups
    @administrative_groups = rest_proxy.get("/v3/users/#{ self.uid }/administrative_groups").parse or []
  end

  def administrative_groups=(group_ids)
    rest_proxy.put("/v3/users/#{ self.uid }/administrative_groups", :json => { "ids" => group_ids }).parse
  end

  def teaching_group
    return @teaching_group if @teaching_group
    @teaching_group = rest_proxy.get("/v3/users/#{ self.uid }/teaching_group").parse or {}
  end

  def teaching_group=(group_id)
    rest_proxy.put("/v3/users/#{ self.uid }/teaching_group", :params => { "id" => group_id }).parse
  end

  def year_class
    return @year_class if @year_class
    @year_class = rest_proxy.get("/v3/users/#{ self.uid }/year_class").parse or {}
  end

  private

  # Find role object by name (role_name) and set id to role_ids array.
  #
  # set_role_ids_by_role_name method is run when validate object (see "validate" method).
  #
  # update_roles method run after save. update_roles join roles to user by role id (role_ids).
  #
  # This makes it possible for that you can also set user's role by name.
  # user = User.first
  # user.role_name = "Administrator"
  # user.save
  def set_role_ids_by_role_name(name)
    unless role_name.nil?
      role = Role.find( :all,
                        :attribute => "displayName",
                        :value => name).delete_if{ |r| r.puavoSchool != self.puavoSchool }.first
      if role.nil?
        return false
      else
        self.role_ids = Array(role.id)
      end
    end
    return true
  end

  def set_special_ldap_value
    self.displayName = self.givenName + " " + self.sn
    self.cn = self.uid
    self.homeDirectory = "/home/" + self.uid unless self.uid.nil?
    self.gidNumber = self.school.gidNumber unless self.puavoSchool.nil?
    set_uid_number if self.uidNumber.nil?
    self.puavoId = IdPool.next_puavo_id if self.puavoId.nil?
    set_samba_settings if self.sambaSID.nil?
    unless self.gidNumber.nil? || self.puavoSchool.nil?
      self.sambaPrimaryGroupSID = "#{SambaDomain.first.sambaSID}-#{self.school.puavoId}"
    end
    self.loginShell = '/bin/bash'
    self.eduPersonPrincipalName = "#{self.uid}@#{LdapOrganisation.current.puavoKerberosRealm}"
    if self.puavoAllowRemoteAccess.class == String
      self.puavoAllowRemoteAccess = case self.puavoAllowRemoteAccess
                                    when "true"
                                      true
                                    when "false"
                                      false
                                    end
    end
    self.puavoEduPersonReverseDisplayName = self.sn + " " + self.givenName
  end

  def set_uid_number
    self.uidNumber = IdPool.next_uid_number
  end

  # FIXME: This method is used only cucumber test. Move this methmod to test code.
  def set_school_admin
    if self.school_admin == "true"
      self.school.puavoSchoolAdmin = Array(self.school.puavoSchoolAdmin).push self.dn
      self.school.save!
    end
  end

  def is_uid_changed
    unless self.puavoId.nil?
      begin
        old_user = User.find(self.puavoId)
        if self.uid != old_user.uid
          self.uid_has_changed = true

          logger.debug "User uid has changed. Remove memberUid from roles and groups"
          unless new_group_management?(self.school)
            Role.search_as_utf8( :filter => "(memberUid=#{old_user.uid})",
                                 :scope => :one,
                                 :attributes => ['dn'] ).each do |role_dn, values|
              LdapBase.ldap_modify_operation(role_dn, :delete, [{"memberUid" => [old_user.uid.to_s]}])
            end
          end

          Group.search_as_utf8( :filter => "(memberUid=#{old_user.uid})",
                        :scope => :one,
                        :attributes => ['dn'] ).each do |group_dn, values|
            LdapBase.ldap_modify_operation(group_dn, :delete, [{"memberUid" => [old_user.uid.to_s]}])
          end
          School.search_as_utf8( :filter => "(memberUid=#{old_user.uid})",
                         :scope => :one,
                         :attributes => ['dn'] ).each do |school_dn, values|
            LdapBase.ldap_modify_operation(school_dn, :delete, [{"memberUid" => [old_user.uid.to_s]}])
          end
          # Remove uid from Domain Users group
          SambaGroup.delete_uid_from_memberUid('Domain Users', old_user.uid)
        end
      rescue ActiveLdap::EntryNotFound
      end
    end
  end

  def add_member_uid_to_models
    if self.uid_has_changed
      logger.debug "User uid has changed. Add new uid to roles and groups if it not exists"
      self.uid_has_changed = false

      unless new_group_management?(self.school)
        self.roles.each do |role|
          role.ldap_modify_operation( :add, [{"memberUid" => [self.uid.to_s]}] )
        end
      end

      self.groups.each do |group|
        group.ldap_modify_operation( :add, [{"memberUid" => [self.uid.to_s]}] )
      end
    end
    unless Array(self.school.memberUid).include?(self.uid)
      self.school.ldap_modify_operation( :add, [{"memberUid" => [self.uid.to_s]}] )
    end
    unless Array(self.school.member).include?(self.dn)
      # FIXME
      self.school.ldap_modify_operation( :add, [{"member" => [self.dn.to_s]}] )
    end

    # Set uid to Domain Users group
    SambaGroup.add_uid_to_memberUid('Domain Users', self.uid)
  end

  private

  def delete_all_associations
    # Remove uid from Domain Users group
    SambaGroup.delete_uid_from_memberUid('Domain Users', self.uid)
    if Array(self.puavoAdminOfSchool).count > 0
      SambaGroup.delete_uid_from_memberUid('Domain Admins', self.uid)
    end

    unless new_group_management?(self.school)
      self.roles.each do |p|
        p.delete_member(self)
      end
    end

    self.groups.each do |g|
      g.remove_user(self)
    end

    self.school.remove_user(self)
  end

  def delete_kerberos_principal
    # XXX We should really destroy the kerberos principal for this user,
    # XXX but for now we just set a password to some unknown value
    # XXX so that the kerberos principal can not be used.
    self.new_password = generate_password(40)
    change_password(:no_upstream)
  end

  def set_samba_settings
    self.sambaSID = SambaDomain.next_samba_sid
    self.sambaAcctFlags = "[U]"
  end

end

# FIXME: this code have to move to better place.
module ActiveLdap
  module Association
    class BelongsTo < Proxy
      # Overwrite to_s method.
      # Example usage: user.primary_group.to_s, return example: "Class 4"
      def to_s
        # exists?-method load target (example group object) and returns true if found it
        if self.exists?
          return self.target.to_s
        end
        return ""
      end
    end
  end
end
