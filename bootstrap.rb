#!/usr/bin/ruby
require 'rubygems'
require 'erb'
require 'ostruct'
require 'fileutils'
require 'yaml'
require 'inquirer'

DEFAULTS = File.exist?("defaults.yml") ? YAML::load_file("defaults.yml") : {}

def run(cmd)
  puts "[Running] #{cmd}"
  `#{cmd}` unless ENV['DEBUG']
end

def install
    puts "======================================================"
    puts "Setting up ZSH"
    puts "======================================================"
    install_oh_my_zsh()
    switch_to_zsh()

    puts "======================================================"
    puts "Installing Homebrew deprendencies"
    puts "======================================================"
    install_brew_dependencies()

    puts "======================================================"
    puts "Installing some pips"
    puts "======================================================"
    install_pip_dependencies()

    puts "======================================================"
    puts "Installing Node version manager (NVM)"
    puts "======================================================"
    install_nvm()

    puts "======================================================"
    puts "Installing RVM"
    puts "======================================================"
    install_rvm()

    puts "======================================================"
    puts "Installing Rust"
    puts "======================================================"
    install_rust()

    puts "======================================================"
    puts "Customize OSX"
    puts "======================================================"
    customize_osx()

    puts "======================================================"
    puts "Symlinking files"
    puts "======================================================"
    files = get_files_to_process()
    puts "Processing:\n "
    files.each { |f| puts "\t#{f}" }
    puts
    puts

    file_options = %w{yes no always}
    always_overwrite = false
    files.each do |src_filename|
        f = src_filename.split("/", 2)[1] # Get rid of the "dotfiles/" prefix
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

                if !always_overwrite
                    response = Ask.list("File already exists: #{target_filename}. Overwrite it?", file_options)
                    always_overwrite = true if (file_options[response].to_sym == :always)
                    should_overwrite = always_overwrite or response == 1
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

def get_files_to_process
    files = Dir.glob("dotfiles/**/*") - %w[bootstrap.rb defaults.yml README.md LICENSE oh-my-zsh .gitignore ]
    files.reject! { |f| File.directory?(f) }
    files
end

def is_erb?(f)
    f.end_with?(".erb")
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
    File.exist?(File.join(ENV['HOME'], ".oh-my-zsh"))
end

def brew_installed?
    return !run("which brew").empty?
end

def zsh_active?
    ENV["SHELL"] =~ /zsh/
end

def switch_to_zsh
    if zsh_active?
        puts "using zsh"
        return
    end

    should_switch = Ask.confirm("Switch to oh-my-zsh??", clear: true, response: false, default: true)
    if should_switch
        puts "switching to zsh"
        system %Q{chsh -s `which zsh`}
    end
end

def install_oh_my_zsh
    if zsh_installed?
        puts "found ~/.oh-my-zsh"
        return
    end

    should_install = Ask.confirm("Install oh-my-zsh??", clear: true, response: false, default: true)
    if should_install
        puts "installing oh-my-zsh"
        system %Q{git clone https://github.com/robbyrussell/oh-my-zsh.git "$HOME/.oh-my-zsh"}
    end
end

def iTerm_available_themes
   Dir['iTerm2/*.itermcolors'].map { |value| File.basename(value, '.itermcolors')} << 'None'
end

def iTerm_profile_list
  profiles=Array.new
  begin
    profiles <<  %x{ /usr/libexec/PlistBuddy -c "Print :'New Bookmarks':#{profiles.size}:Name" ~/Library/Preferences/com.googlecode.iterm2.plist 2>/dev/null}
  end while $?.exitstatus==0
  profiles.pop
  profiles
end

def apply_theme_to_iterm_profile_idx(index, color_scheme_path)
  values = Array.new
  16.times { |i| values << "Ansi #{i} Color" }
  values << ['Background Color', 'Bold Color', 'Cursor Color', 'Cursor Text Color', 'Foreground Color', 'Selected Text Color', 'Selection Color']
  values.flatten.each { |entry| run %{ /usr/libexec/PlistBuddy -c "Delete :'New Bookmarks':#{index}:'#{entry}'" ~/Library/Preferences/com.googlecode.iterm2.plist } }

  run %{ /usr/libexec/PlistBuddy -c "Merge '#{color_scheme_path}' :'New Bookmarks':#{index}" ~/Library/Preferences/com.googlecode.iterm2.plist }
  run %{ defaults read com.googlecode.iterm2 }
end

def install_brew_dependencies
    if !brew_installed?
        run 'ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"'
    end
    run %{brew cask install java}

    run %{brew tap homebrew/cask-fonts}
    run %{brew cask install font-hack-nerd-font}
    run %{brew install starship}

    run %{brew install vim ack direnv git watch tree python go graphviz ffmpeg httpie boost curl wget webp libxml2 libyaml archey gnupg gnupg2 carthage swiftlint jq terraform protobuf}
    run %{brew install kubectx}
    run %{brew install libvorbis openal-soft}

    browsers = "google-chrome firefox"
    if Ask.confirm("Install browsers? (#{browsers})", clear: true, response: false, default: true)
      run %{brew cask install #{browsers}}
    end

    dev_tools = "iterm2 tower visual-studio-code jetbrains-toolbox docker"
    if Ask.confirm("Install dev tools? (#{dev_tools})", clear: true, response: false, default: true)
      run %{brew cask install #{dev_tools}}
    end

    tools = "spectacle vlc the-unarchiver go2shell zoomus notion"
    if Ask.confirm("Install essential utils? (#{tools})", clear: true, response: false, default: true)
      run %{brew cask install #{tools}}
    end

    fun = "boxer"
    if Ask.confirm("Install fun stuff? (#{fun})", clear: true, response: false, default: true)
      run %{brew cask install #{fun}}
    end
end

def install_pip_dependencies
    run %{pip3 install -U pip setuptools virtualenv}
    run %{pip3 install git-sweep httpie}
end

def install_nvm
  run %{curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash}
end

def install_rvm
  run %{curl -sSL https://get.rvm.io | bash -s head}
end

def install_rust
    run %{curl https://sh.rustup.rs -sSf | sh -s -- -v -y}
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

  puts "Restarting apps..."
  %w(Finder Terminal ).each do |app|
    run %{sudo killall #{app}}
  end

  run %{open /System/Library/CoreServices/Finder.app}
  puts "Done. Note that some of these changes require a logout/restart to take effect."
end

install
