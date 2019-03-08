<div class="master-docs">
This the documentation for the git master branch. For the current production
documentation please see
<a href="https://api.opinsys.fi/v3/sso/developers">https://api.opinsys.fi/v3/sso/developers</a>
</div>

# Opinsys Authentication

For now to implement Opinsys Authentication to a external service you must receive a
shared secret from Opinsys support `tuki aet opinsys.fi`. To receive it you
must provide following:

  - Fully qualified domain name (fqdn)
    - The service must be available on this domain
  - Optionally a path prefix for the service
    - Required only if multiple external services must be served from the same
      domain with different shared secrets
  - Name and small description of the service
    - Will be displayed on the login form and admin configuration panel for
      school admins
  - Email address of the service maintainer
  - Optionally a link describing the service in more detail


Once the shared sercret is in place the external service may redirect
user's web browser to `https://api.opinsys.fi/v3/sso` with a `return_to`
query string key which determines where user is redirected back. The hostname
of the `return_to` URL must match with the fqdn provided to us.

Example redirect URL might be:

    https://api.opinsys.fi/v3/sso?return_to=http%3A%2F%2Fexample.com

When user is authenticated he/she will be redirected to the URL specified in
the `return_to` query string key. The URL is augmented with a `jwt` query string
key which will contain a [JSON Web Token][jwt]. The external service is
expected to decode this token, validate it with the given shared secret and
make sure that it is not issued too long a ago or in future. The token will
contain following claims:

  - `iat` Identifies the time at which the JWT was issued as unix timestamp
  - `jti` A unique identifier for the JWT
  - `id` Unique identifier for the user
  - `username`
  - `first_name`
  - `last_name`
  - `email` User email
    - Not available always
  - `primary_school_id`
    - The school id user primarily attends to
  - `schools` List of school objects user belongs to
    - `id` Unique identifier for the school
    - `name` Human readable school name
    - `abbreviation` Valid POSIX name for the school
    - `roles` List of roles (String) user has in the school
      - `teacher`, `staff`, `student`, `visitor`, `parent`, `admin`, `schooladmin` or `testuser`
    - `groups` List of group objects user has in the school
      - `id` Unique identifier for the school
      - `name` Human readable group name
      - `abbreviation` Valid POSIX name for the group
      - `type` Type of the group (String)
          - `teaching group`, `year class`, `administrative group`, `course`, `archive users` or `other groups`
  - `organisation_name`
    - Human readable organisation name.
  - `organisation_domain`
    - For example `jyvaskyla.opinsys.fi`.

In addition to those above, there are some "extra" fields that can be used, but
you should NOT rely on their existence (they might not always exist). These are:

  - `puavo_id`
    - This is the actual internal unique ID for this user. It's the same as `id` but this field gives it an explicit name.
  - `external_id`
    - External IDs (social security number hash) for users who attend a school that has Primus integration enabled. Will be null for others.
  - `preferred_language`
    - Two-letter language code (`en`, `fi`, `sv`, `de` and so on) identifying the language this user primarily speaks. Can be used to localize the environment.
  - `year_class`
    - A string containing the year class name for students who attend a school that has Primus integration enabled. Will be always `null` (the actual JSON NULL value, not a string!) for non-students and students who are not in a Primus-enabled school.

## Service activation

By default external services are not activated for all Opinsys organisations.
Each organisation or individual schools must activate the external services on
their behalf. They can do this directly from their management interface.

## Organisation presetting

If the external service knows in advance from which organisation the user
is coming from it can make the login bit easier by specifying an additional
query string key `organisation` to the redirect URL:

    https://api.opinsys.fi/v3/sso?organisation=kehitys.opinsys.fi&return_to=http%3A%2F%2Fexample.com

Using this users don't have to manually type their organisation during login.

## Kerberos

When user is coming from a Opinsys managed desktop Kerberos will be used for
the authentication. User will not even see the Opinsys login form in this case.
He/she will be directly redirected back to `return_to` url with a `jwt` key.
The organisation presetting is ignored when Kerberos is active because the
organisation will read from the Kerberos ticket. This is enabled by default for
all external services using Opinsys Authentication.

## Custom fields

If you need to relay some custom fields through the Authentication service you
can just add them to the `return_to` URL. Just remember to escape the value.


Example:

    https://api.opinsys.fi/v3/sso?return_to=http%3A//example.com/path%3Fcustom_field%3Dbar

Redirects user to:

    http://example.com/path?custom_field=bar&jwt=<the jwt token>


## Implementation help

  - [JSON Web Token draft][jwt]
  - Known working JSON Web Token implementations
    - For [Ruby](https://github.com/progrium/ruby-jwt)
    - For [node.js](https://npmjs.org/package/jwt-simple)
  - [Express][] middleware implementation: [node-jwtsso][]
  - Example [external service](https://github.com/opinsys/node-jwtsso/blob/master/example/app.js)

Feel free to contact us at `dev aet opinsys.fi` or open up an issue on
[Github][issue] if you have any trouble implementing this. You can also send a
[pull request][pr] to this document if you feel it is missing something.

[jwt]: http://tools.ietf.org/html/draft-jones-json-web-token

[node-jwtsso]: https://github.com/opinsys/node-jwtsso
[Express]: http://expressjs.com/
[issue]: https://github.com/opinsys/puavo-users/issues
[pr]: https://github.com/opinsys/puavo-users/blob/master/rest/doc/SSO_DEVELOPERS.md
