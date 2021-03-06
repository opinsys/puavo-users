Rails.application.routes.draw do

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root :to => "schools#index"

  match '/menu' => 'menu#index', :via => :get

  get "/quick_search" => "quick_search#index" #, :as => :search_index
  get '/extended_search' => 'extended_search#index'
  post '/extended_search' => 'extended_search#do_search', via: [:options]

  get '/all_devices' => 'organisations#all_devices'
  get '/get_all_devices' => 'organisations#get_all_devices'
  get '/all_images' => 'image_statistics#all_images'
  get '/all_users' => 'organisations#all_users'
  get '/get_all_users' => 'organisations#get_all_users'
  get '/all_groups' => 'organisations#all_groups'
  get '/get_all_groups' => 'organisations#get_all_groups'

  # On-the-fly UI language changing
  get '/change_language' => 'sessions#change_language'

  scope :path => "restproxy" do
    match '(*url)' => 'rest#proxy', :via => [:get, :post, :put], :format => false
  end

  scope :path => "users" do
    resources :ldap_services
    resource :organisation_external_services

    scope :path => ':school_id' do
      resource :rename_groups
    end

    namespace :schools do
      scope :path => ':school_id' do
        resource :external_services
      end
    end

    scope :path => ':school_id' do
      resources :printer_permissions
    end

    scope :path => ':school_id' do
      match 'lists' => 'lists#index', :as => :lists, :via => :get
      match 'lists/:id' => 'lists#download', :as => :download_list, :via => :post
      match 'lists/:id' => 'lists#delete', :as => :delete_list, :via => :delete
    end

    match 'schools/:id/admins' => 'schools#admins', :as => :admins_school, :via => :get
    match 'schools/:id/add_school_admin/:user_id' => 'schools#add_school_admin', :as => :add_school_admin_school, :via => :put
    match 'schools/:id/remove_school_admin/:user_id' => 'schools#remove_school_admin', :as => :remove_school_admin_school, :via => :put
    match 'schools/:id/wlan' => 'schools#wlan', :as => :wlan_school, :via => :get
    match 'schools/:id/wlan_update' => 'schools#wlan_update', :as => :wlan_update_school, :via => :patch
    match 'schools/:id/external_services' => 'external_services#index', :as => :external_services_school, :via => :get
    resources :schools

    scope :path => ':school_id' do
      match "groups/:id/remove_user/:user_id" => "groups#remove_user", :as => "remove_user_group", :via => :put
      match 'groups/:id/create_username_list_from_group' => 'groups#create_username_list_from_group', :as => "create_username_list_from_group", :via => :put
      match 'groups/:id/mark_group_members_for_deletion' => 'groups#mark_group_members_for_deletion', :as => "mark_group_members_for_deletion", :via => :put
      match 'groups/:id/unmark_group_members_deletion' => 'groups#unmark_group_members_deletion', :as => "unmark_group_members_deletion", :via => :put
      match 'groups/:id/lock_all_members' => 'groups#lock_all_members', :as => "lock_all_members", :via => :put
      match 'groups/:id/unlock_all_members' => 'groups#unlock_all_members', :as => "unlock_all_members", :via => :put
      match 'groups/:id/delete_all_group_members' => 'groups#delete_all_group_members', :as => "delete_all_group_members", :via => :delete
      match "groups/:id/add_user/:user_id" => "groups#add_user", :as => "add_user_group", :via => :put
      match "groups/:id/user_search" => "groups#user_search", :as => :user_search, :via => :get
      get 'groups/:id/get_members_as_csv' => 'groups#get_members_as_csv', :as => :get_members_as_csv
      put 'groups/:id/remove_all_members' => 'groups#remove_all_members', :as => :remove_all_members

      get 'get_school_groups_list' => 'groups#get_school_groups_list'

      post 'mass_op_group_delete' => 'groups#mass_op_group_delete'

      get 'groups/find_groupless_users' => 'groups#find_groupless_users', :as => :find_groupless_users
      put 'groups/mark_groupless_users_for_deletion' => 'groups#mark_groupless_users_for_deletion', :as => :mark_groupless_users_for_deletion

      get 'groups/:id/members' => 'groups#members'

      match 'users/:id/group' => 'users#group', :as => :group_user, :via => :get
      match 'users/:id/add_group' => 'users#add_group', :as => :add_group_user, :via => :put
      match 'import_tool' => 'import_tool#index', :via => :get
      match 'username_redirect/:username' => 'users#username_redirect', :via => :get, :constraints => { :username => /[^\/]+/ }
      match 'users/:id/mark_user_for_deletion' => 'users#mark_for_deletion', :as => :mark_user_for_deletion, :via => :get
      match 'users/:id/unmark_user_for_deletion' => 'users#unmark_for_deletion', :as => :unmark_user_for_deletion, :via => :get
      match 'users/:id/prevent_deletion' => 'users#prevent_deletion', :as => :prevent_deletion, :via => :get

      match 'users/:id/change_schools' => 'users#change_schools', :as => :change_schools, :via => :get
      match 'users/:id/change_schools/add_school/:school' => 'users#add_to_school', :as => :add_user_to_school, :via => :get
      match 'users/:id/change_schools/remove_school/:school' => 'users#remove_from_school', :as => :remove_user_from_school, :via => :get
      match 'users/:id/change_schools/set_primary_school/:school' => 'users#set_primary_school', :as => :set_user_primary_school, :via => :get
      match 'users/:id/change_schools/add_and_set_primary_school/:school' => 'users#add_and_set_primary_school', :as => :add_and_set_user_primary_school, :via => :get
      match 'users/:id/change_schools/move_to_school/:school' => 'users#move_to_school', :as => :move_to_school, :via => :get

      get 'get_school_users_list' => 'users#get_school_users_list'

      post 'mass_op_user_delete' => 'users#mass_op_user_delete'
      post 'mass_op_user_lock' => 'users#mass_op_user_lock'
      post 'mass_op_user_mark' => 'users#mass_op_user_mark'
      post 'mass_op_user_clear_column' => 'users#mass_op_user_clear_column'
      post 'mass_op_username_list' => 'users#mass_op_username_list'

    end


    scope :path => ':school_id' do
      resources :users
      match 'users/:id/image' => 'users#image', :as => :image_user, :via => :get
    end

    resources :users

    scope :path => ':school_id' do
      resources :groups
    end
    resources :groups

    get '/login' => 'sessions#new', :as => :login
    post '/login' => 'sessions#create'
    match '/logout' => 'sessions#destroy', :as => :logout, :via => :delete

    resources :sessions
    get 'schools/:id/image' => 'schools#image', :as => :image_school
    get '/' => 'schools#index'

    scope :path => "password" do
      get( '', :to => 'password#edit',
           :as => :password )
      get( 'edit',
           :to => 'password#edit',
           :as => :edit_password )
      get( 'own',
           :to => 'password#own',
           :as => :own_password )
      put( '',
           :to => 'password#update' )
      get( 'forgot',
           :to => 'password#forgot',
           :as => :forgot_password )
      put( 'forgot',
           :to => 'password#forgot_send_token',
           :as => :forgot_send_token_password )
      get( ':jwt/reset',
           :to => 'password#reset',
           :as => :reset_password,
           constraints: { jwt: /.+/ } )
      post( ':jwt/reset',
            :to => 'password#reset_update',
            :as => :reset_update_password,
            constraints: { jwt: /.+/ } )
      get( 'successfully/:message',
           :to => 'password#successfully',
           :as => :successfully_password )
    end

    match( 'email_confirm' => 'email_confirm#confirm',
           :as => :confirm_email,
           :via => :put )
    match( 'email_confirm/successfully' => 'email_confirm#successfully',
           :as => :successfully_email_confirm,
           :via => :get )
    match( 'email_confirm/:jwt' => 'email_confirm#preview',
           :as => :preview_email_confirm,
           :via => :get,
           :constraints => { jwt: /.+/ } )

    get 'themes/:theme' => 'themes#set_theme', :as => :set_theme
    resources :admins

    match 'owners' => 'organisations#owners', :as => :owners_organisation, :via => :get
    match 'remove_owner/:user_id' => 'organisations#remove_owner', :as => :remove_owner_organisations, :via => :put
    match 'add_owner/:user_id' => 'organisations#add_owner', :as => :add_owner_organisations, :via => :put

    match 'wlan' => 'organisations#wlan', :as => :wlan_organisation, :via => :get
    match 'wlan_update' => 'organisations#wlan_update', :as => :wlan_update_organisation, :via => :patch

    resource :organisation, :only => [:show, :edit, :update]
    resource :profile, :only => [:edit, :update, :show]
    get "profile/image" => "profiles#image", :as => :image_profile
  end

  scope :path => "devices" do
    get '/' => 'schools#index'

    match 'sessions/show' => 'api/v1/sessions#show', :via => :get
    resources :sessions

    get 'hosts/types' => 'hosts#types'

    scope :path => ':school_id' do
      match 'devices/:id/select_school' => 'devices#select_school', :as => 'select_school_device', :via => :get
      match 'devices/:id/change_school' => 'devices#change_school', :as => 'change_school_device', :via => :post
      match 'devices/:id/image' => 'devices#image', :as => 'image_device', :via => :get

      get 'devices/device_statistics' => 'image_statistics#school_images', :as => 'school_image_statistics'

      get 'get_school_devices_list' => 'devices#get_school_devices_list'

      post 'mass_op_device_change_school' => 'devices#mass_op_device_change_school'
      post 'mass_op_device_delete' => 'devices#mass_op_device_delete'
      post 'mass_op_device_set_image' => 'devices#mass_op_device_set_image'
      post 'mass_op_device_set_field' => 'devices#mass_op_device_set_field'
      post 'mass_op_device_edit_puavoconf' => 'devices#mass_op_device_edit_puavoconf'
      post 'mass_op_device_purchase_info' => 'devices#mass_op_device_purchase_info'

      resources :devices

      match( 'devices/:id/revoke_certificate' => 'devices#revoke_certificate',
             :as => 'revoke_certificate_device',
             :via => :delete )

    end

    match 'servers/:id/image' => 'servers#image', :as => 'image_server', :via => :get
    match( 'servers/:id/revoke_certificate' => 'servers#revoke_certificate',
           :as => 'revoke_certificate_server',
           :via => :delete )
    resources :servers

    get 'get_servers_list' => 'servers#get_servers_list'

    namespace :api do
      namespace :v2 do
        match( 'devices/by_hostname/:hostname' => 'devices#by_hostname',
               :as => 'by_hostname_api_v2_device',
               :via => :get )
        resources :devices
        resources :servers
      end
    end

    resources :printers, :except => [:show, :new]

    match '/auth' => 'sessions#auth', :via => :get

  end

    namespace :api do
      namespace :v2 do
        match( 'hosts/sign_certificate' => 'hosts#sign_certificate',
               :as => 'hosts_sign_certificate',
               :via => :post,
               :format => :json )
      end
    end

  ["", "api/v2/"].each do |prefix|
    new_prefix = prefix.gsub("/", "_")
    match("#{ prefix }external_files" => "external_files#index", :via => :get)
    match("#{ prefix }external_files" => "external_files#upload", :via => :post)
    match(
      "#{ prefix }external_files/:name" => "external_files#get_file",
      :name => /.+/,
      :format => false,
      :via => :get,
      :as => "#{new_prefix}download_external_file"
    )
    match(
      "#{ prefix }external_files/:name" => "external_files#destroy",
      :name => /.+/,
      :format => false,
      :via => :delete,
      :as => "#{new_prefix}destroy_external_file"
    )
  end

  # Final catch-all route, 404 everything from this point on
  if ENV["RAILS_ENV"] == "production"
    match "*path", to: "application#send_404", via: :all
  end

end
