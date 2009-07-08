def www_aliases
  "#{domain} #{extra_domains}".split(' ').compact.map(&:strip).reject {|d|
    d.starts_with?('www.')
  }.map {|d|
    "www.#{d}"
  }.join(' ')
end

dep 'vhost enabled' do
  requires 'vhost configured'
  met? { File.exists? "/opt/nginx/conf/vhosts/on/#{domain}.conf" }
  meet { sudo "ln -sf '/opt/nginx/conf/vhosts/#{domain}.conf' '/opt/nginx/conf/vhosts/on/#{domain}.conf'" }
  after { restart_nginx }
end

dep 'vhost configured' do
  requires 'webserver configured'
  met? { %w[conf common].all? {|suffix| File.exists? "/opt/nginx/conf/vhosts/#{domain}.#{suffix}" } }
  meet {
    render_erb 'nginx/vhost.conf.erb',   :to => "/opt/nginx/conf/vhosts/#{domain}.conf"
    render_erb 'nginx/vhost.common.erb', :to => "/opt/nginx/conf/vhosts/#{domain}.common"
  }
end

# TODO duplication
dep 'proxy enabled' do
  requires 'proxy configured'
  met? { File.exists? "/opt/nginx/conf/vhosts/on/#{domain}.conf" }
  meet { sudo "ln -sf '/opt/nginx/conf/vhosts/#{domain}.conf' '/opt/nginx/conf/vhosts/on/#{domain}.conf'" }
  after { restart_nginx }
end

dep 'proxy configured' do
  requires 'webserver configured'
  met? { File.exists? "/opt/nginx/conf/vhosts/#{domain}.conf" }
  meet {
    render_erb 'nginx/http_proxy.conf.erb', :to => "/opt/nginx/conf/vhosts/#{domain}.conf"
  }
end

def build_nginx opts = {}
  in_dir "~/src/", :create => true do
    get_source("http://sysoev.ru/nginx/nginx-#{opts[:nginx_version]}.tar.gz") and
    get_source("http://www.grid.net.ru/nginx/download/nginx_upload_module-#{opts[:upload_module_version]}.tar.gz") and
    log_shell("Building nginx (this takes a minute or two)", "sudo passenger-install-nginx-module", :input => [
      '', # enter to continue
      '2', # custom build
      File.expand_path("nginx-#{opts[:nginx_version]}"), # path to nginx source
      '', # accept /opt/nginx target path
      "--with-http_ssl_module --add-module='#{File.expand_path "nginx_upload_module-#{opts[:upload_module_version]}"}'",
      '', # confirm settings
      '', # enter to continue
      '' # done
      ].join("\n")
    )
  end
end

def nginx_running?
  shell "netstat -an | grep -E '^tcp.*[.:]80 +.*LISTEN'"
end

def restart_nginx
  if nginx_running?
    log_shell "Restarting nginx", "/opt/nginx/sbin/nginx -s reload", :sudo => true
  end
end

dep 'webserver running' do
  requires 'webserver configured', 'webserver startup script'
  met? {
    returning nginx_running? do |result|
      result "There is #{result ? 'something' : 'nothing'} listening on #{result ? result.scan(/[0-9.*]+[.:]80/).first : 'port 80'}", :result => result
    end
  }
  meet {
    if linux?
      sudo '/etc/init.d/nginx start'
    elsif osx?
      log_error "launchctl should have already started nginx. Check /var/log/system.log for errors."
    end
  }
end

dep 'webserver startup script' do
  requires 'webserver installed', 'rcconf'
  met? {
    if linux?
      shell("rcconf --list").val_for('nginx') == 'on'
    elsif osx?
      sudo('launchctl list') {|shell| shell.stdout.split("\n").grep 'org.nginx' }
    end
  }
  meet {
    if linux?
      render_erb 'nginx/nginx.init.d', :to => '/etc/init.d/nginx', :perms => '755'
      sudo 'update-rc.d nginx defaults'
    elsif osx?
      render_erb 'nginx/nginx.launchd', :to => '/Library/LaunchDaemons/org.nginx.plist'
      sudo 'launchctl load -w /Library/LaunchDaemons/org.nginx.plist'
    end
  }
end

dep 'webserver configured' do
  requires 'webserver installed', 'www user and group'
  met? {
    if !File.exists?('/opt/nginx/conf/nginx.conf')
      unmet "there is no nginx config"
    elsif !grep(/Generated by babushka/, '/opt/nginx/conf/nginx.conf')
      unmet "the nginx config needs to be regenerated"
    else
      current_passenger_version = IO.read('/opt/nginx/conf/nginx.conf').val_for('passenger_root')
      returning current_passenger_version.ends_with?(Babushka::GemHelper.has?('passenger').to_s) do |result|
        log_result "nginx is configured to use #{File.basename current_passenger_version}", :result => result
      end
    end
  }
  meet {
    set :passenger_version, Babushka::GemHelper.has?('passenger', :log => false)
    render_erb 'nginx/nginx.conf.erb', :to => '/opt/nginx/conf/nginx.conf'
  }
  after {
    sudo "mkdir -p /opt/nginx/conf/vhosts/on"
    restart_nginx
  }
end

dep 'webserver installed' do
  requires 'passenger', 'build tools', 'libssl headers', 'zlib headers'
  met? { File.executable?('/opt/nginx/sbin/nginx') }
  meet { build_nginx :nginx_version => '0.7.60', :upload_module_version => '2.0.9' }
end
