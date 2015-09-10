#
# Author: Joe Damato
# Module Name: packagecloud
#
# Copyright 2014-2015, Computology, LLC
#
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

define packagecloud::repo(
  $type = undef,
  $fq_name = undef,
  $master_token = undef,
  $priority = undef,
  $server_address = 'https://packagecloud.io',
  $gpg_key_fingerprint = '418A7F2FB0E1E6E7EABF6FE8C2E73424D59097AB',
) {
  validate_string($type)
  validate_string($master_token)

  include packagecloud

  if $fq_name != undef {
    $repo_name = $fq_name
  } else {
    $repo_name = $name
  }

  $normalized_name = regsubst($repo_name, '\/', '_')

  if $master_token != undef {
    $read_token = get_read_token($repo_name, $master_token, $server_address)
    $base_url = build_base_url($read_token, $server_address)
  } else {
    $base_url = $server_address
  }

  if $type == 'gem' {
    exec { "install packagecloud ${repo_name} repo as gem source":
      command => "gem source --add ${base_url}/${repo_name}/",
      unless  => "gem source --list | grep ${base_url}/${repo_name}",
    }
  } elsif $type == 'deb' {
    $osname = downcase($::operatingsystem)
    case $osname {
      'debian', 'ubuntu': {

        include apt
        
        $component = 'main'
        $repo_url = "${base_url}/${repo_name}/${osname}"
        $distribution =  $::lsbdistcodename

        apt::source { $normalized_name:
          comment     => $normalized_name,
          ensure      => 'present',
          location    => $repo_url,
          release     => $distribution,
          repos       => $component,
          include     => {
            'deb'     => true,
            'src'     => true,
          },
          key         => {
            'id'      => $gpg_key_fingerprint,
            'server'  => $server_address,
            'source'  => "${server_address}/gpg.key",
          },
        }
      }

      default: {
        fail("Sorry, ${::operatingsystem} isn't supported for apt repos at this time. Email support@packagecloud.io")
      }
    }
  } elsif $type == 'rpm' {
    case $::operatingsystem {
      'RedHat', 'redhat', 'CentOS', 'centos', 'Amazon', 'Fedora', 'Scientific', 'OracleLinux', 'OEL': {
        
        if $read_token {
          if $::osreleasemaj == '5' {
            $yum_repo_url = $::operatingsystem ? {
              /(RedHat|redhat|CentOS|centos)/ => "${server_address}/priv/${read_token}/${repo_name}/el/5/${::architecture}/",
              /(OracleLinux|OEL)/             => "${server_address}/priv/${read_token}/${repo_name}/ol/5/${::architecture}/",
              'Scientific'                    => "${server_address}/priv/${read_token}/${repo_name}/scientific/5/${::architecture}/",
            }
          } else {
            $yum_repo_url = $::operatingsystem ? {
              /(RedHat|redhat|CentOS|centos)/ => "${base_url}/${repo_name}/el/${$::osreleasemaj}/${::architecture}/",
              /(OracleLinux|OEL)/             => "${base_url}/${repo_name}/ol/${$::osreleasemaj}/${::architecture}/",
              'Scientific'                    => "${base_url}/${repo_name}/scientific/${$::osreleasemaj}/${::architecture}/",
            }
          }
        } else {
          $yum_repo_url = $::operatingsystem ? {
            /(RedHat|redhat|CentOS|centos)/ => "${base_url}/${repo_name}/el/${$::osreleasemaj}/${::architecture}/",
            /(OracleLinux|OEL)/             => "${base_url}/${repo_name}/ol/${$::osreleasemaj}/${::architecture}/",
            'Scientific'                    => "${base_url}/${repo_name}/scientific/${$::osreleasemaj}/${::architecture}/",
          }
        }

        $repo_url = $::operatingsystem ? {
          /(RedHat|redhat|CentOS|centos|Scientific|OracleLinux|OEL)/ => $yum_repo_url,
          'Fedora' => "${base_url}/${repo_name}/fedora/${$::osreleasemaj}/${::architecture}/",
          'Amazon' => "${base_url}/${repo_name}/el/6/${::architecture}",
        }

        $repo_gpgcheck = $::osreleasemaj ? {
          '5'     => 0,
          default => 1,
        }

        yumrepo { $normalized_name:
          baseurl       => $repo_url, 
          descr         => $normalized_name,
          enabled       => 1,
          ensure        => 'present',
          gpgcheck      => 0,
          gpgkey        => "${base_url}/gpg.key",
          priority      => $priority,
          repo_gpgcheck => $repo_gpgcheck,
          sslcacert     => '/etc/pki/tls/certs/ca-bundle.crt',
          sslverify     => 1,
        }
      }

      default: {
        fail("Sorry, ${::operatingsystem} isn't supported for yum repos at this time. Email support@packagecloud.io")
      }
    }
  }

}
