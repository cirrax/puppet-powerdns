override_facts = {
  root_home: '/root'
}

require 'spec_helper'
describe 'powerdns', type: :class do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) do
          facts.merge(override_facts)
        end

        case facts[:osfamily]
        when 'RedHat'
          authoritative_package_name = 'pdns'
          authoritative_service_name = 'pdns'
          authoritative_config = '/etc/pdns/pdns.conf'
          mysql_schema_file = '/usr/share/doc/pdns-backend-mysql-4.?.?/schema.mysql.sql'
          pgsql_backend_package_name = 'pdns-backend-postgresql'
          pgsql_schema_file = '/usr/share/doc/pdns-backend-postgresql-4.?.?/schema.pgsql.sql'
          sqlite_backend_package_name = 'pdns-backend-sqlite'
          sqlite_binary_package_name = 'sqlite'
          sqlite_schema_file = '/usr/share/doc/pdns-backend-sqlite-4.?.?/schema.sqlite.sql'
          recursor_package_name = 'pdns-recursor'
          recursor_service_name = 'pdns-recursor'
        when 'Debian'
          authoritative_package_name = 'pdns-server'
          authoritative_service_name = 'pdns'
          authoritative_config = '/etc/powerdns/pdns.conf'
          mysql_schema_file = '/usr/share/doc/pdns-backend-mysql/schema.mysql.sql'
          pgsql_backend_package_name = 'pdns-backend-pgsql'
          pgsql_schema_file = '/usr/share/doc/pdns-backend-pgsql/schema.pgsql.sql'
          sqlite_backend_package_name = 'pdns-backend-sqlite3'
          sqlite_schema_file = '/usr/share/doc/pdns-backend-sqlite3/schema.sqlite3.sql'
          sqlite_binary_package_name = 'sqlite3'
          recursor_package_name = 'pdns-recursor'
          recursor_service_name = 'pdns-recursor'
        end

        context 'powerdns class without parameters' do
          it {
            is_expected.to raise_error(
              %r{'db_password' must be a non-empty string when 'authoritative' == true},
            )
          }
        end

        context 'powerdns class with require_db_password at false' do
          let :params do
            {
              require_db_password: false
            }
          end

          it {
            is_expected.to raise_error(
              %r{On MySQL 'db_root_password' must be a non-empty string when 'backend_create_tables' == true},
            )
          }
        end

        context 'powerdns class with require_db_password at false and backend postgresql' do
          let :params do
            {
              require_db_password: false,
              backend: 'postgresql'
            }
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_powerdns__config('gpgsql-password') }
        end

        context 'powerdns class with require_db_password at false and backend_create_tables at false' do
          let :params do
            {
              require_db_password: false,
              backend_create_tables: false
            }
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_powerdns__config('gmysql-password') }
        end

        context 'powerdns class with parameters' do
          let(:params) do
            {
              db_root_password: 'foobar',
              db_username: 'foo',
              db_password: 'bar'
            }
          end

          it { is_expected.to contain_class('powerdns::params') }

          # Check the repositories
          it { is_expected.to contain_class('powerdns::repo') }
          case facts[:osfamily]
          when 'RedHat'
            it { is_expected.to contain_package('yum-plugin-priorities') } if facts[:operatingsystemmajrelease].to_i < 8
            it { is_expected.to contain_yumrepo('powertools') } if facts[:operatingsystemmajrelease].to_i >= 8
            if facts[:operatingsystem] != 'Rocky' && facts[:operatingsystemmajrelease].to_i >= 8
              it {
                is_expected.to contain_yumrepo('powertools').with('mirrorlist' => 'http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=PowerTools&infra=$infra')
              }
            end
            if facts[:operatingsystem] == 'Rocky' && facts[:operatingsystemmajrelease].to_i >= 8
              it {
                is_expected.to contain_yumrepo('powertools').with('mirrorlist' => 'https://mirrors.rockylinux.org/mirrorlist?arch=$basearch&repo=PowerTools-$releasever')
              }
            end
            it { is_expected.to contain_yumrepo('powerdns') }
            it { is_expected.to contain_yumrepo('powerdns').with('baseurl' => 'http://repo.powerdns.com/centos/$basearch/$releasever/auth-42') }
            it { is_expected.to contain_yumrepo('powerdns-recursor') }
            it { is_expected.to contain_yumrepo('powerdns-recursor').with('baseurl' => 'http://repo.powerdns.com/centos/$basearch/$releasever/rec-42') }
          end
          case facts[:osfamily]
          when 'Debian'
            it { is_expected.to contain_apt__key('powerdns') }
            it { is_expected.to contain_apt__pin('powerdns') }
            it { is_expected.to contain_apt__source('powerdns') }
            it { is_expected.to contain_apt__source('powerdns').with_release(%r{auth-42}) }
            it { is_expected.to contain_apt__source('powerdns-recursor') }
            it { is_expected.to contain_apt__source('powerdns-recursor').with_release(%r{rec-42}) }

            # On Ubuntu 17.04 and higher and Debian 9 and higher it expects dirmngr
            if (facts[:operatingsystem] == 'Ubuntu' && facts[:operatingsystemmajrelease].to_i >= 17) ||
               (facts[:operatingsystem] == 'Debian' && facts[:operatingsystemmajrelease].to_i >= 9)
              it { is_expected.to contain_package('dirmngr') }
            end
          end

          # Check the authoritative server
          it { is_expected.to contain_class('powerdns::authoritative') }
          it { is_expected.to contain_package(authoritative_package_name).with('ensure' => 'installed') }
          it { is_expected.to contain_service('pdns').with('ensure' => 'running') }
          it { is_expected.to contain_service('pdns').with('enable' => 'true') }
          it { is_expected.to contain_service('pdns').with('name' => authoritative_service_name) }
          it { is_expected.to contain_service('pdns').that_requires("Package[#{authoritative_package_name}]") }
        end

        context 'powerdns class with epel' do
          let(:params) do
            {
              db_root_password: 'foobar',
              db_username: 'foo',
              db_password: 'bar'
            }
          end

          it { is_expected.to compile.with_all_deps }

          case facts[:osfamily]
          when 'RedHat'
            it { is_expected.to contain_class('epel') }
          end
        end

        context 'powerdns class with epel' do
          let(:params) do
            {
              db_root_password: 'foobar',
              db_username: 'foo',
              db_password: 'bar',
              custom_epel: true
            }
          end

          it { is_expected.to compile.with_all_deps }

          case facts[:osfamily]
          when 'RedHat'
            it { is_expected.not_to contain_class('epel') }
          end
        end

        context 'powerdns class with different version' do
          let(:params) do
            {
              db_root_password: 'foobar',
              db_username: 'foo',
              db_password: 'bar',
              version: '4.0'
            }
          end

          it { is_expected.to compile.with_all_deps }

          case facts[:osfamily]
          when 'RedHat'
            it { is_expected.to contain_yumrepo('powerdns').with('baseurl' => 'http://repo.powerdns.com/centos/$basearch/$releasever/auth-40') }
            it { is_expected.to contain_yumrepo('powerdns-recursor').with('baseurl' => 'http://repo.powerdns.com/centos/$basearch/$releasever/rec-40') }
          when 'Debian'
            it { is_expected.to contain_apt__source('powerdns').with_release(%r{auth-40}) }
            it { is_expected.to contain_apt__source('powerdns-recursor').with_release(%r{rec-40}) }
          end
        end

        context 'powerdns class with mysql backend' do
          let(:params) do
            {
              db_host: '127.0.0.1',
              db_root_password: 'foobar',
              db_username: 'foo',
              db_password: 'bar',
              db_port: 3307,
              backend: 'mysql'
            }
          end

          it { is_expected.to contain_class('powerdns::backends::mysql') }
          it { is_expected.to contain_package('pdns-backend-mysql').with('ensure' => 'installed') }
          it { is_expected.to contain_mysql__db('powerdns').with('user' => 'foo', 'password' => 'bar', 'host' => '127.0.0.1') }
          it { is_expected.to contain_mysql__db('powerdns').with_sql(mysql_schema_file) }

          # This sets our configuration
          it { is_expected.to contain_powerdns__config('gmysql-host').with('value' => '127.0.0.1') }
          it { is_expected.to contain_powerdns__config('gmysql-dbname').with('value' => 'powerdns') }
          it { is_expected.to contain_powerdns__config('gmysql-password').with('value' => 'bar') }
          it { is_expected.to contain_powerdns__config('gmysql-user').with('value' => 'foo') }
          it { is_expected.to contain_powerdns__config('gmysql-port').with('value' => 3307) }
          it { is_expected.to contain_powerdns__config('launch').with('value' => 'gmysql') }

          it { is_expected.to contain_file_line('powerdns-config-gmysql-host-%{config}' % { config: authoritative_config }) }
          it { is_expected.to contain_file_line('powerdns-config-gmysql-dbname-%{config}' % { config: authoritative_config }) }
          it { is_expected.to contain_file_line('powerdns-config-gmysql-password-%{config}' % { config: authoritative_config }) }
          it { is_expected.to contain_file_line('powerdns-config-gmysql-user-%{config}' % { config: authoritative_config }) }
          it { is_expected.to contain_file_line('powerdns-config-gmysql-port-%{config}' % { config: authoritative_config }) }
          it { is_expected.to contain_file_line('powerdns-config-launch-%{config}' % { config: authoritative_config }) }
        end

        context 'powerdns class with postgresql backend' do
          let(:params) do
            {
              db_root_password: 'foobar',
              db_username: 'foo',
              db_password: 'bar',
              backend: 'postgresql'
            }
          end

          it { is_expected.to contain_class('powerdns::backends::postgresql') }

          if facts[:operatingsystem] == 'Debian'
            it { is_expected.to contain_file('/etc/powerdns/pdns.d/pdns.local.gpgsql.conf').with('ensure' => 'absent') }
            it { is_expected.to contain_package('pdns-backend-bind').with('ensure' => 'purged') }
          end

          it { is_expected.to contain_package(pgsql_backend_package_name).with('ensure' => 'installed') }
          it { is_expected.to contain_postgresql__server__db('powerdns').with('user' => 'foo') }
          it { is_expected.to contain_postgresql_psql('Load SQL schema').with('command' => "\\i #{pgsql_schema_file}") }

          it { is_expected.to contain_powerdns__config('launch').with('value' => 'gpgsql') }
          it { is_expected.to contain_powerdns__config('gpgsql-host').with('value' => 'localhost') }
          it { is_expected.to contain_powerdns__config('gpgsql-dbname').with('value' => 'powerdns') }
          it { is_expected.to contain_powerdns__config('gpgsql-password').with('value' => 'bar') }
          it { is_expected.to contain_powerdns__config('gpgsql-user').with('value' => 'foo') }

          it { is_expected.to contain_file_line("powerdns-config-gpgsql-host-#{authoritative_config}") }
          it { is_expected.to contain_file_line("powerdns-config-gpgsql-dbname-#{authoritative_config}") }
          it { is_expected.to contain_file_line("powerdns-config-gpgsql-password-#{authoritative_config}") }
          it { is_expected.to contain_file_line("powerdns-config-gpgsql-user-#{authoritative_config}") }
        end

        context 'powerdns class with sqlite backend' do
          let(:params) do
            {
              db_file: '/var/lib/powerdns/db.sqlite3',
              backend: 'sqlite'
            }
          end

          it { is_expected.to contain_class('powerdns::backends::sqlite') }
          it { is_expected.to contain_package(sqlite_backend_package_name).with('ensure' => 'installed') }
          it { is_expected.to contain_package(sqlite_binary_package_name).with('ensure' => 'installed') }
          it do
            is_expected.to contain_file('/var/lib/powerdns/db.sqlite3').with(
              'ensure' => 'present',
              'owner' => 'pdns',
              'group' => 'pdns',
              'mode' => '0644',
            )
          end
          it do
            is_expected.to contain_file('/var/lib/powerdns').with(
              'ensure' => 'directory',
              'owner' => 'pdns',
              'group' => 'pdns',
              'mode' => '0755',
            )
          end

          it do
            is_expected.to contain_exec('powerdns-sqlite3-create-tables').with(
              'command' => "/usr/bin/env sqlite3 /var/lib/powerdns/db.sqlite3 < #{sqlite_schema_file}",
            )
          end
          it { is_expected.to contain_powerdns__config('launch').with('value' => 'gsqlite3') }
          it { is_expected.to contain_powerdns__config('gsqlite3-database').with('value' => '/var/lib/powerdns/db.sqlite3') }

          it { is_expected.to contain_file_line('powerdns-config-gsqlite3-database-%{config}' % { config: authoritative_config }) }
        end

        context 'powerdns class with bind backend' do
          let(:params) do
            {
              backend: 'bind'
            }
          end

          it { is_expected.to contain_class('powerdns::backends::bind') }

          case facts[:osfamily]
          when 'RedHat'
            it { is_expected.to contain_file('/etc/pdns/named.conf').with('ensure' => 'file') }
            it { is_expected.to contain_file('/etc/pdns/named').with('ensure' => 'directory') }
            it { is_expected.to contain_file('/etc/pdns/pdns.d/pdns.simplebind.conf').with('ensure' => 'absent') }
            it { is_expected.to contain_powerdns__config('bind-config').with('value' => '/etc/pdns/named.conf') }
          end
          case facts[:osfamily]
          when 'Debian'
            it { is_expected.to contain_file('/etc/powerdns/named.conf').with('ensure' => 'file') }
            it { is_expected.to contain_file('/etc/powerdns/named').with('ensure' => 'directory') }
            it { is_expected.to contain_file('/etc/powerdns/pdns.d/pdns.simplebind.conf').with('ensure' => 'absent') }
            it { is_expected.to contain_powerdns__config('bind-config').with('value' => '/etc/powerdns/named.conf') }
          end

          it { is_expected.to contain_powerdns__config('launch').with('value' => 'bind') }

          it { is_expected.to contain_file_line('powerdns-config-bind-config-%{config}' % { config: authoritative_config }) }
          it { is_expected.to contain_file_line('powerdns-config-launch-%{config}' % { config: authoritative_config }) }
          it { is_expected.to contain_file_line(format('powerdns-bind-baseconfig')) }
        end

        context 'powerdns class with ldap backend' do
          context 'with backend_install and backend_create_tables set to false' do
            let(:params) do
              {
                ldap_basedn: 'ou=foo',
                ldap_binddn: 'foo',
                ldap_secret: 'bar',
                backend: 'ldap',
                backend_install: false,
                backend_create_tables: false
              }
            end

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to contain_class('powerdns::backends::ldap') }
            it { is_expected.to contain_package('pdns-backend-ldap').with('ensure' => 'installed') }
            it { is_expected.to contain_package('pdns-backend-bind').with('ensure' => 'purged') } if facts[:operatingsystem] == 'Debian'
            it { is_expected.to contain_powerdns__config('launch').with('value' => 'ldap') }
            it { is_expected.to contain_powerdns__config('ldap-host').with('value' => 'ldap://localhost/') }
            it { is_expected.to contain_powerdns__config('ldap-basedn').with('value' => 'ou=foo') }
            it { is_expected.to contain_powerdns__config('ldap-secret').with('value' => 'bar') }
            it { is_expected.to contain_powerdns__config('ldap-binddn').with('value' => 'foo') }
            it { is_expected.to contain_powerdns__config('ldap-method').with('value' => 'strict') }

            it { is_expected.to contain_file_line('powerdns-config-ldap-host-%{config}' % { config: authoritative_config }) }
            it { is_expected.to contain_file_line('powerdns-config-ldap-basedn-%{config}' % { config: authoritative_config }) }
            it { is_expected.to contain_file_line('powerdns-config-ldap-secret-%{config}' % { config: authoritative_config }) }
            it { is_expected.to contain_file_line('powerdns-config-ldap-binddn-%{config}' % { config: authoritative_config }) }
            it { is_expected.to contain_file_line('powerdns-config-ldap-method-%{config}' % { config: authoritative_config }) }
          end

          context 'with backend_install set to true' do
            let(:params) do
              {
                ldap_basedn: 'ou=foo',
                ldap_binddn: 'foo',
                ldap_secret: 'bar',
                backend: 'ldap',
                backend_install: true,
                backend_create_tables: false
              }
            end

            it 'fails with backend_install' do
              is_expected.to raise_error(%r{backend_install is not supported with ldap})
            end
          end

          context 'with backend_create_tables set to true' do
            let(:params) do
              {
                ldap_basedn: 'ou=foo',
                ldap_binddn: 'foo',
                ldap_secret: 'bar',
                backend: 'ldap',
                backend_install: false,
                backend_create_tables: true
              }
            end

            it 'fails' do
              is_expected.to raise_error(%r{backend_create_tables is not supported with ldap})
            end
          end
        end

        context 'powerdns class with backend_create_tables set to false' do
          let(:params) do
            {
              db_root_password: 'foobar',
              db_username: 'foo',
              db_password: 'bar',
              backend: 'mysql',
              backend_create_tables: false
            }
          end

          # Tables aren't created and neither is the database
          it { is_expected.not_to contain_mysql__db('powerdns').with('user' => 'foo', 'password' => 'bar', 'host' => 'localhost') }

          it { is_expected.not_to contain_powerdns__backends__mysql__create_table('comments') }
          it { is_expected.not_to contain_powerdns__backends__mysql__create_table('cryptokeys') }
          it { is_expected.not_to contain_powerdns__backends__mysql__create_table('domainmetadata') }
          it { is_expected.not_to contain_powerdns__backends__mysql__create_table('domains') }
          it { is_expected.not_to contain_powerdns__backends__mysql__create_table('records') }
          it { is_expected.not_to contain_powerdns__backends__mysql__create_table('supermasters') }
          it { is_expected.not_to contain_powerdns__backends__mysql__create_table('tsigkeys') }
        end

        # Test the recursor
        context 'powerdns class with the recursor enabled and the authoritative server disabled' do
          let(:params) do
            {
              db_root_password: 'foobar',
              db_username: 'foo',
              db_password: 'bar',
              recursor: true,
              authoritative: false
            }
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('powerdns::params') }

          # Check the authoritative server
          it { is_expected.to contain_class('powerdns::recursor') }
          it { is_expected.to contain_package(recursor_package_name).with('ensure' => 'installed') }
          it { is_expected.to contain_service('pdns-recursor').with('ensure' => 'running') }
          it { is_expected.to contain_service('pdns-recursor').with('enable' => 'true') }
          it { is_expected.to contain_service('pdns-recursor').with('name' => recursor_service_name) }
          it { is_expected.to contain_service('pdns-recursor').that_requires('Package[%{package}]' % { package: recursor_package_name }) }
        end

        # Test errors
        context 'powerdns class with an empty database username' do
          let(:params) do
            {
              db_root_password: 'foobar',
              db_username: '',
              db_password: 'bar'
            }
          end

          it { is_expected.to raise_error(%r{parameter 'db_username' expects a(.*)String}) }
        end

        context 'powerdns class without database password' do
          let(:params) do
            {
              db_root_password: 'foobar',
              db_username: 'foo'
            }
          end

          it {
            is_expected.to raise_error(
              %r{'db_password' must be a non-empty string when 'authoritative' == true},
            )
          }
        end

        context 'powerdns class with an unsupported backend' do
          let(:params) do
            {
              db_root_password: 'foobar',
              db_username: 'foo',
              db_password: 'bar',
              backend: 'awesomedb'
            }
          end

          it {
            is_expected.to raise_error(
              %r{'backend' expects a match for Enum\['bind', 'ldap', 'mysql', 'postgresql', 'sqlite'\]},
            )
          }
        end

        context 'powerdns version 4.7' do
          let(:params) do
            {
              db_root_password: 'foobar',
              db_username: 'foo',
              db_password: 'bar',
              version: '4.7'
            }
          end

          case facts[:osfamily]
          when 'RedHat'
            it {
              is_expected.to contain_yumrepo('powerdns') \
                .with('baseurl' => 'http://repo.powerdns.com/centos/$basearch/$releasever/auth-47')
            }
            it {
              is_expected.to contain_yumrepo('powerdns-recursor') \
                .with('baseurl' => 'http://repo.powerdns.com/centos/$basearch/$releasever/rec-47')
            }
          when 'Debian'
            it { is_expected.to contain_apt__source('powerdns').with_release(%r{auth-47}) }
            it { is_expected.to contain_apt__source('powerdns-recursor').with_release(%r{rec-47}) }
          end

          it { is_expected.to contain_package(authoritative_package_name).with('ensure' => 'installed') }
        end

        context 'powerdns class with the recursor with forward zones' do
          let(:params) do
            {
              recursor: true,
              authoritative: false,
              forward_zones: {
                'example.com': '1.1.1.1',
                '+.': '8.8.8.8'
              }
            }
          end

          case facts[:osfamily]
          when 'RedHat'
            recursor_dir = '/etc/pdns-recursor'
          when 'Debian'
            recursor_dir = '/etc/powerdns'
          end

          it { is_expected.to compile.with_all_deps }

          # Check the authoritative server
          it { is_expected.to contain_class('powerdns::recursor') }
          it { is_expected.to contain_file("#{recursor_dir}/forward_zones.conf").with_ensure('file') }
          it {
            is_expected.to contain_powerdns__config('forward-zones-file') \
              .with(value: "#{recursor_dir}/forward_zones.conf")
          }

          it {
            is_expected.to contain_file("#{recursor_dir}/forward_zones.conf") \
              .with_content(%r{^example.com=1.1.1.1})
          }
        end
      end
    end
  end
end
