#!/usr/bin/ruby
require 'rubygems'
require 'erb'
require 'ostruct'
require 'fileutils'
require 'yaml'
require 'inquirer'

DEFAULTS = File.exist?('defaults.yml') ? YAML::load_file('defaults.yml') : {}

def run(cmd)
  puts "[Running] #{cmd}"
  `#{cmd}` unless ENV['DEBUG']
end

def install
  puts "======================================================"
  puts "Setting up ZSH"
  puts "======================================================"
  install_oh_my_zsh
  switch_to_zsh

  puts "======================================================"
  puts "Installing Homebrew deprendencies"
  puts "======================================================"
  install_brew_dependencies

  puts "======================================================"
  puts "Installing some pips"
  puts "======================================================"
  install_pip_dependencies

  puts "======================================================"
  puts "Installing Rust"
  puts "======================================================"
  install_rust

  puts "======================================================"
  puts "Customize OSX"
  puts "======================================================"
  customize_osx

  puts "======================================================"
  puts "Symlinking files"
  puts "======================================================"
  symlink_files
  symlink_folders

  puts "======================================================"
  puts "Done!"
  puts "======================================================"
end

FOLDERS_NOT_TO_SYMLINK = ["dotfiles/oh-my-zsh", "dotfiles/ssh"]

def symlink_folders()
  # iterm is a special case
  folders = Dir.glob('dotfiles/*') - FOLDERS_NOT_TO_SYMLINK
  folders.select! { |f| File.directory?(f) }
  folders.sort!

  puts "Processing:\n "

  file_options = %w{yes no always}
  always_overwrite = false

  folders.each do |folder_name|
    f = folder_name.split('/', 2)[1] # Get rid of the "dotfiles/" prefix
    src = File.absolute_path(folder_name)
    target = File.join(ENV['HOME'], ".#{f}")

    if File.exist?(target)
      should_overwrite = always_overwrite
      unless should_overwrite
        response = Ask.list("File already exists: #{target}. Overwrite it?", file_options)
        always_overwrite =  (file_options[response].to_sym == :always)
        should_overwrite = always_overwrite || (file_options[response].to_sym == :yes)
      end

      unless should_overwrite
        puts "Skipping #{src}"
        next
      end
    end

    puts "\tSymlinking #{target} -> #{src}"
    FileUtils.rm_r(target) if File.directory?(target)
    FileUtils.ln_s(src, target, force: true)
  end
end

def symlink_files
  files = Dir.glob('dotfiles/*')
  FOLDERS_NOT_TO_SYMLINK.each { |f| 
    files = files + Dir.glob(f + '/**/*')
  }
  files.reject! { |f| File.directory?(f) }
  puts "Processing:\n "
  files.each { |f| puts "\t#{f}" }
  puts
  puts

  file_options = %w{yes no always}
  always_overwrite = false
  files.each do |src_filename|
    f = src_filename.split('/', 2)[1] # Get rid of the "dotfiles/" prefix
    src_fullname = File.absolute_path(src_filename)

    puts %Q{mkdir -p "$HOME/.#{File.dirname(f)}"} if f =~ /\//
    system %Q{mkdir -p "$HOME/.#{File.dirname(f)}"} if f =~ /\//

    target_filename = File.join(ENV['HOME'], ".#{f.sub(/\.erb$/, '')}")
    puts "Processing: #{f} => #{target_filename} - #{File.exist?(target_filename)}"
    if File.exist?(target_filename)
      if File.identical?(f, target_filename)
        puts "\tfiles are identical"
      else
        should_overwrite = always_overwrite || Ask.confirm("File already exists: #{target_filename}. Overwrite it?", clear: true, response: false, default: false)

        unless always_overwrite
          response = Ask.list("File already exists: #{target_filename}. Overwrite it?", file_options)
          always_overwrite = true if (file_options[response].to_sym == :always)
          should_overwrite = always_overwrite || (file_options[response].to_sym == :yes)
        end

        if should_overwrite
          puts "\tRemoving #{target_filename}"
          FileUtils.rm_f(target_filename)
        else
          puts "\tSkipping #{target_filename}"
          next
        end
      end
    end

    process_file(src_fullname, target_filename)
  end
end

def is_erb?(f)
  f.end_with?('.erb')
end

def process_file(f, target_filename)
  # ERB - render the erb template to target location
  # Other - symlink

  if is_erb?(f)
    puts "\tGenerating #{target_filename}"
    erb_template = File.read(f)
    erb = ERB.new(erb_template)
    erb_rendered = ERB.new(erb_template).result(OpenStruct.new(DEFAULTS).instance_eval { binding })

    File.open(target_filename, 'w') do |new_file|
      new_file.write(erb_rendered)
    end
  else
    puts "\tSymlinking #{target_filename} => #{f}"
    FileUtils.ln_s(f, target_filename, force: true)
  end
end

def zsh_installed?
  File.exist?(File.join(ENV['HOME'], '.oh-my-zsh'))
end

def brew_installed?
  !run('which brew').empty?
end

def rust_installed?
  !run('which rustup').empty?
end

def asdf_installed?
  !run('which asdf').empty?
end

def zsh_active?
  ENV['SHELL'] =~ /zsh/
end

def switch_to_zsh
  if zsh_active?
    puts 'using zsh'
    return
  end

  should_switch = Ask.confirm('Switch to oh-my-zsh??', clear: true, response: false, default: true)
  if should_switch
    puts 'switching to zsh'
    system 'chsh -s `which zsh`'
  end
end

def install_oh_my_zsh
  if zsh_installed?
    puts 'found ~/.oh-my-zsh'
    return
  end

  should_install = Ask.confirm('Install oh-my-zsh??', clear: true, response: false, default: true)
  if should_install
    puts 'installing oh-my-zsh'
    system 'git clone https://github.com/robbyrussell/oh-my-zsh.git "$HOME/.oh-my-zsh"'
  end
end

def install_brew_dependencies
  unless brew_installed?
    puts "Install Homebrew first!"
    exit!
  end

  puts "Installing basic homebrew packages..."
  run %{brew tap homebrew/cask-fonts}
  run %{brew install cask font-hack-nerd-font}
  run %{brew install atuin coreutils asdf starship flycut vim ack direnv git watch tree zlib graphviz ffmpeg httpie boost curl wget webp libxml2 libyaml carthage jq terraform protobuf kubectx fzf zoxide}
  run %{brew install libvorbis openal-soft}

  puts "Installing Google Cloud SDK..."
  run %{brew install google-cloud-sdk krew}
  run %{gcloud components install docker-credential-gcr cloud-build-local kustomize}

  unless asdf_installed?
    puts "Installing ASDF"
    run %{brew install asdf}
    run %{. /usr/local/opt/asdf/libexec/asdf.sh}
  end
  run %{asdf plugin-add python}
  run %{asdf plugin-add poetry https://github.com/asdf-community/asdf-poetry.git}  
  run %{asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git}
  run %{asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git}
  run %{asdf plugin-add golang https://github.com/kennyp/asdf-golang.git}
  run %{asdf install python latest}
  run %{asdf install poetry latest}
  run %{asdf install ruby latest}
  run %{asdf install golang latest}
  run %{asdf install nodejs latest}
  run %{asdf install terraform latest}

  dev_tools = 'iterm2 tower docker'
  if Ask.confirm("Install dev tools? (#{dev_tools})", clear: true, response: false, default: true)
    run %{brew install --cask #{dev_tools}}
  end

  tools = 'rectangle vlc the-unarchiver'
  if Ask.confirm("Install essential utils? (#{tools})", clear: true, response: false, default: true)
    run %{brew install --cask #{tools}}
  end

  fun = 'boxer'
  if Ask.confirm("Install fun stuff? (#{fun})", clear: true, response: false, default: true)
    run %{brew install --cask #{fun}}
  end
end

def install_pip_dependencies
  run %{pip3 install -U pip}
  run %{pip3 install git-sweep}
end

def install_rust
  unless rust_installed?
    run %{curl https://sh.rustup.rs -sSf | sh -s -- -v -y}
  end
  run %{cargo install bat exa du-dust fd-find ripgrep hyperfine tokei sd ytop bandwhich procs gping}
end

def customize_osx
  ###############################################################################
  # Finder
  ###############################################################################
  run %{defaults write com.apple.finder AppleShowAllFiles YES}

  # Show icons for hard drives, servers, and removable media on the desktop
  run %{defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true}
  run %{defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true}
  run %{defaults write com.apple.finder ShowMountedServersOnDesktop -bool true}
  run %{defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true}

  # Finder: show all filename extensions
  run %{defaults write NSGlobalDomain AppleShowAllExtensions -bool true}

  # Finder: show status bar
  run %{defaults write com.apple.finder ShowStatusBar -bool true}

  # Finder: show path bar
  run %{defaults write com.apple.finder ShowPathbar -bool true}

  ###############################################################################
  # iTerm2
  ###############################################################################
  # Don’t display the annoying prompt when quitting iTerm
  run %{defaults write com.googlecode.iterm2 PromptOnQuit -bool false}
  # Specify the preferences directory
  run %{defaults write com.googlecode.iterm2.plist PrefsCustomFolder -string "~/.iterm2"}
  # Tell iTerm2 to use the custom preferences in the directory
  run %{defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true}

  ###############################################################################
  # Activity Monitor                                                            #
  ###############################################################################
  # Show the main window when launching Activity Monitor
  run %{defaults write com.apple.ActivityMonitor OpenMainWindow -bool true}

  # Visualize CPU usage in the Activity Monitor Dock icon
  run %{defaults write com.apple.ActivityMonitor IconType -int 5}

  # Show all processes in Activity Monitor
  run %{defaults write com.apple.ActivityMonitor ShowCategory -int 0}

  # Sort Activity Monitor results by CPU usage
  run %{defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"}
  run %{defaults write com.apple.ActivityMonitor SortDirection -int 0}

  puts 'Restarting apps...'
  %w(Finder).each do |app|
    run %{sudo killall #{app}}
  end

  run %{open /System/Library/CoreServices/Finder.app}
  puts 'Done. Note that some of these changes require a logout/restart to take effect.'
end

install
