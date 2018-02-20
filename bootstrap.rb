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
    puts "Installing nenv"
    puts "======================================================"
    # install_nenv()

    puts "======================================================"
    puts "Installing Android SDK"
    puts "======================================================"
    # install_android_sdk()

    puts "======================================================"
    puts "Installing Atom packages"
    puts "======================================================"
    # install_atom_packages()

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
        puts "Processing: #{f} => #{target_filename}"
        if File.exist?(target_filename)
            if File.identical?(f, target_filename)
                puts "\tfiles are identical"
            else
                # should_overwrite = Ask.confirm("File already exists: #{target_filename}. Overwrite it?", clear: true, response: false, default: false)

                should_overwrite = always_overwrite
                if !always_overwrite
                    response = Ask.list("File already exists: #{target_filename}. Overwrite it?", file_options)
                    always_overwrite = true if (file_options[response].to_sym == :always)
                    should_overwrite = always_overwrite or response == 1
                end

                if should_overwrite
                    puts "\tRemoving #{target_filename}"
                    FileUtils.rm(target_filename)
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
        FileUtils.ln_s(f, target_filename)
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
    run %{brew tap homebrew/science}
    run %{brew tap caskroom/cask}
    run %{brew tap caskroom/versions}

    run %{brew cask install java}
    run %{brew install git watch tree python scipy numpy graphviz scala redis memcached apache-spark ffmpeg httpie boost curl wget webp libxml2 libyaml archey gnupg gnupg2 carthage swiftlint packer}

    if Ask.confirm("Install browsers? (google-chrome google-chrome-canary firefox safari-technology-preview)", clear: true, response: false, default: true)
      run %{brew cask install google-chrome google-chrome-canary firefox safari-technology-preview}
    end

    if Ask.confirm("Install dev tools? (iterm2 atom tower)", clear: true, response: false, default: true)
      run %{brew cask install iterm2 atom tower}
    end

    if Ask.confirm("Install essential utils? (dropbox vlc lastpass hipchat slack screenflow, spectacle the-unarchiver)", clear: true, response: false, default: true)
      run %{brew cask install dropbox vlc lastpass hipchat slack screenflow, spectacle the-unarchiver}
    end
end

def install_pip_dependencies
    run %{pip install -U pip setuptools virtualenv}
    run %{pip install git-sweep pivotal_tools httpie}
end

def install_android_sdk
    should_run = Ask.confirm("Update Android SDK?", clear: true, response: false, default: true)
    return if !should_run

    # Update or install SDK components.
    # Install platform-tools to get adb.
    run %{echo y | android update sdk --no-ui --all --filter "tools","platform-tools"}
    # Install Build Tools (23.0.2 is necessary to build using gradle).
    run %{echo y | android update sdk --no-ui --all --filter "build-tools","build-tools-23.0.2"}
    # Install Google Play Services.
    run %{echo y | android update sdk --no-ui --all --filter "extra-google-google_play_services"}
end

def install_atom_packages
  should_run = Ask.confirm("Install Atom packages?", clear: true, response: false, default: true)
  return if !should_run

  run %{apm install seti-ui editorconfig todo-show pigments atom-beautify prettier-atom highlight-selected sort-lines toggle-quotes color-picker linter linter-ui-default linter-eslint}
end

def install_nenv
    nenv_path = File.expand_path('~/.nenv')
    if !Dir.exists?(nenv_path)
        run %{git clone https://github.com/ryuone/nenv.git ~/.nenv}
    end
    run %{export PATH=$PATH:~/.nenv}  # just to make sure
    run %{nenv rehash}
    puts "Installing NodeJS 7.4.0"
    run %{nenv install 7.10.0}
    puts "Installing NodeJS 6.9.4"
    run %{nenv install 6.9.4}
end

install
