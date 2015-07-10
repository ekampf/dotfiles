# ekampf does dotfiles

## dotfiles

@ekampf's dotfiles
Your dotfiles are how you personalize your system. These are mine.


## Install

Clone the repo (Or fork it...):
    git clone git://github.com/ekampf/dotfiles.git

Install required gems:
    bundle install

Run the bootstrap script:
    ./bootstrap.rb

#### Personalize

Put your customizations in dotfiles appended with `.local`:

* `~/.aliases.local`
* `~/.gitconfig.local`
* `~/.tmux.conf.local`
* `~/.vimrc.local`
* `~/.zshenv.local`
* `~/.zshrc.local`

For example, your `~/.aliases.local` might look like this:

    # Productivity
    alias todo='$EDITOR ~/.todo'
    
    # Easy Folder access
    alias go='cd $HOME/Documents/workspace'

And so on...


#### Whats in it?

<TODO>

tmux configuration:

* Improve color resolution.
* Remove administrative debris (session name, hostname, time) in status bar.
* Set prefix to `Ctrl+s`
* Soften status bar color from harsh green to light gray.
