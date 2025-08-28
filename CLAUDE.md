## Isolation

You are running in an isolated container.  Your access to the filesystem is ONLY to the current folder.  You have network access, but you cannot find files outside of the current working directory.  Do not try to access files outside of the
current	working	directory.  If you try to run a command and it's not in the docker container, do not look elsewhere and do not try to install it.  In that case, stop and ask the developer to modify the dockert container.

## Tracking Context

Whenever you run, create a hiddent directory .claude-tracking and inside that create file and summarize your context.  This is not for normal use, but is intended to help the developer regain context if they have to stop you to add functionality to the containr.  On restart, the developer can ask you to read that file to regain context.  Always add the folder .claude-tracking to .gitignore.

## Branch Policy and Strategy

The user works on multiple projects that have different repositories, policies and strategies.  The user is also forgetful to update the local repository when staring sessions.

REMIND the user to consider the appropriate branching strategy when starting a session or a series of tasks.  This reminder should include 
- current branch and status 
- suggestions to pull, push, create or delete branches





