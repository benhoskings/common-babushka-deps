dep 'web repo', :path do
  requires [
    'web repo exists'.with(path),
    'web repo hooks'.with(path),
    'web repo always receives'.with(path),
    'bundler.gem'
  ]
  met? {
    vanity_path = path.p.sub(/^#{Etc.getpwuid(Process.euid).dir.chomp('/')}/, '~')
    log "All done. The repo's URI: " + "#{shell('whoami')}@#{shell('hostname -f')}:#{vanity_path}".colorize('underline')
    true
  }
end

dep 'web repo always receives', :path do
  requires 'web repo exists'.with(path)
  met? { cd(path) { shell?("git config receive.denyCurrentBranch") == 'ignore' } }
  meet { cd(path) { shell("git config receive.denyCurrentBranch ignore") } }
end

dep 'web repo hooks', :path do
  requires 'web repo exists'.with(path)
  met? {
    %w[pre-receive post-receive].all? {|hook_name|
      (path / ".git/hooks/#{hook_name}").executable? &&
      Babushka::Renderable.new(path / ".git/hooks/#{hook_name}").from?(dependency.load_path.parent / "web_repo/#{hook_name}.erb")
    }
  }
  meet {
    cd path, :create => true do
      %w[pre-receive post-receive].each {|hook_name|
        render_erb "web_repo/#{hook_name}.erb", :to => ".git/hooks/#{hook_name}"
        shell "chmod +x .git/hooks/#{hook_name}"
      }
    end
  }
end

dep 'web repo exists', :path do
  requires 'git'
  path.ask("Where should the repo be created").default("~/current")
  met? { (path / '.git').dir? }
  meet {
    cd path, :create => true do
      shell "git init"
    end
  }
end
