meta :locale do
  def locale_regex locale_name
    /#{locale_name}\.utf-?8/i
  end
  def local_locale locale_name
    shell('locale -a').split("\n").detect {|l|
      l[locale_regex(locale_name)]
    }
  end
end

dep 'set.locale', :locale_name do
  locale_name.default!('en_AU')
  requires 'generated.locale'.with(locale_name)
  met? {
    shell('locale').val_for('LANG')[locale_regex(locale_name)]
  }
  meet {
    if Babushka.host.matches?(:arch)
      sudo("echo 'LANG=#{local_locale(locale_name)}' > /etc/locale.conf")
      # Arch doesn't consult /etc/locale.conf on non-interactive logins.
      sudo("echo 'export LANG=#{local_locale(locale_name)}' >> /etc/environment")
    elsif Babushka.host.matches?(:apt)
      sudo("echo 'LANG=#{local_locale(locale_name)}' > /etc/default/locale")
    elsif Babushka.host.matches?(:bsd)
      sudo("echo 'LANG=#{local_locale(locale_name)}' > /etc/profile")
    end
  }
  after {
    log "Setting the locale doesn't take effect until you log out and back in."
  }
end

dep 'generated.locale', :locale_name do
  requires 'enabled.locale'.with(locale_name)
  met? {
    local_locale(locale_name)
  }
  meet {
    shell "locale-gen #{locale_name}.UTF-8", :log => true
  }
end

dep 'enabled.locale', :locale_name do
  met? {
    if !'/etc/locale.gen'.p.exists?
      log_ok "Skipping, since /etc/locale.gen doesn't exist."
    else
      '/etc/locale.gen'.p.read[/^#{locale_regex(locale_name)}/]
    end
  }
  meet {
    '/etc/locale.gen'.p.puts("#{locale_name}.UTF-8 UTF-8")
  }
end
