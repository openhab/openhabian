# Contribution Guidelines

## Pull requests are always welcome

We are always thrilled to receive pull requests, and do our best to process them as fast as possible.
Not sure if that typo is worth a pull request?
Do it!
We will appreciate it.

If your pull request is not accepted on the first try, don't be discouraged!
If there's a problem with the implementation, you will receive feedback on what to improve.

We might decide against incorporating a new feature that does not match the scope of this project.
Get in contact early in the development to propose your idea.

## Conventions

Fork the repo and make changes on your fork in a feature branch.
Then be sure to also provide or update the documentation right when creating or modifying features.

* if adding a new function, see which of the functions/*.bash files it fits in best
* create install_xxx() routine and make it work with arguments "install" and "remove"
* Make sure install_xxx() works in interactive as well as non-interactive (unattended) mode
  If user input is required, create another parameter in openhabian.conf (source for that is in build-image/)
  To test:
  source functions/helpers.bash; source functions/packages.bash; set -x
  install_xxx arg1 arg2 ... argn
* add BATS tests for "install" and "remove"


### Code architecture
Always write clean, modular and testable code.
We have a simple [code-style](#codestyle) which in combination with the static linter [ShellCheck](https://www.shellcheck.net/) works as our coding guidelines.

Every addition to openHABian is supposed to work in both, unattended and interactive mode.
Any 3rd party SW needs an installation routine that takes "install" and "uninstall" as parameters. Calling that from a menu or script branch will then be easy.
Plus when required, do the configuration works in another "setup" routine so it can be called at any later time without un- or reinstalling anything.
Ideally, it even detects and auto-adapts to the version installed so would work with older SW versions as well.
Have a look at the implementation for EVCC in `packages.bash` as a template for 3rd party software.

### Code handling
Pull requests descriptions should be as clear as possible and include a reference to all the issues that they address.
Pull requests must not contain commits from other users or branches.

Commit messages **must** start with a capitalized and short summary (max. 50 chars) written in the imperative, followed by an optional, more detailed explanatory text which is separated from the summary by an empty line.
See [here](https://cbea.ms/git-commit/) for great explanation as to why.

Code review comments may be added to your pull request.
Discuss, then make the suggested modifications and push additional commits to your feature branch.
Be sure to post a comment after pushing.
The new commits will show up in the pull request automatically, but the reviewers will not be notified unless you comment.

Pull requests will be tested on the GitHub Actions platform which **shall** pass.

Any install routine for a new feature must
*   Equally work in a) unattended and b) interactive mode
*   Be tested to execute with a) 'install' and b) 'remove' string arguments,
resulting in installation or removal, respectively.

Please provide [BATS](https://github.com/bats-core/bats-core) test cases for new features to be executed on every build.
The minimum test set to provide is a test to run an unattended installation and automatically validate the feature is working _in principle_.
See [Test Architecture](#test-architecture) below.
Of course, more and more specific test cases are always welcome.

Commits that fix or close an issue should include a reference like `Closes #XXX` or `Fixes #XXX`, which will automatically close the issue when merged.

Before the pull request is merged, your commits might get squashed, based on the size and style of your contribution.
Include documentation changes in the same pull request, so that a revert would remove all traces of the feature or fix.

### Sign your work

The sign-off is a simple line at the end of the explanation for the patch, which certifies that you wrote it or otherwise have the right to pass it on as an open-source patch.
The rules are pretty simple: if you can certify the below (from [developercertificate.org](http://developercertificate.org/)):

```
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.
660 York Street, Suite 102,
San Francisco, CA 94110 USA

Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.


Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.
```

then you just add a line to every git commit message:

```
Signed-off-by: Joe Smith <joe.smith@email.com>
```

using your real name (sorry, no pseudonyms or anonymous contributions) and an e-mail address under which you can be reached (sorry, no GitHub no-reply e-mail addresses (such as username@users.noreply.github.com) or other non-reachable addresses are allowed).

#### Small patch exception

There are several exceptions to the signing requirement.
Currently these are:

*   Your patch fixes spelling or grammar errors.
*   Your patch is a single line change to documentation.

#### Sign your Work using GPG

You can additionally sign your contribution using GPG.
Have a look at the [git documentation](https://git-scm.com/book/tr/v2/Git-Tools-Signing-Your-Work) for more details.
This step is optional and not needed for the acceptance of your pull request.

## Codestyle

Universally formatted code promotes ease of writing, reading, and maintenance.

### Guidelines

*   Use two (2) spaces when indenting code.
*   Use `local variable` declarations of variables wherever possible.
    Always start a function with the declarations of variables.
    The only exception you may have before that is 'short cut' checks that exit the function early if there's conditions in effect that prohibit to proceed with executing the function.
*   Use the short form `local variable=value` to define constants.
*   When using colored output, always use the colors defined in `helpers.bash`.
    For example, `${COL_RED}`, additionally always be sure to reset to standard color at the end of your output statement by using `${COL_DEF}`.
*   Never use absolute paths for binaries, always use the standard paths instead. For example, use `apt-get` instead of `/usr/bin/apt-get`.
*   When a function is used across multiple files, include it in the `helpers.bash` file.
*   Functions should be named using underscores. For example, `new_function`, or `openhabian_update`.
*   Variables should be named using camelCase. For example, `newVariable`, or `requestedArch`.
*   Use all-lowercase global variables for all parametrization in `openhabian.conf`.
    You may not directly read these from inside installation routines (but write if required e.g. to hide passwords after processing).
    Global variables are sourced in as one batch at the beginning of code execution in both run modes.
    Use local variables of the same name but applying camelCase in the install routine and initialize them with the all-lowercase global equivalent's contents before use.
    This is in preparation of a future migration from Shell CLI to a web based interface.
*   Always refuse to allow the running of package setup scripts that require user input in unattended mode.

### Usage of `apt-get update` command

To minimize unnecessary updates of the local apt database running `apt-get update` is only permitted under the following circumstances:

1) Once in the `first-boot.bash` file prior to installing the system first time.

2) Once when the `openhabian-config.sh` script is invoked.

3) When new repository sources are added by installation scripts.

## Test Architecture

Testing is based on three pillars:

A) _Installation of base system_

B) _Test Cases using BATS_

C) _Static analysis using the ShellCheck linter_

### Test installation
Test installations are done continuously using Docker on GitHub and by testing on actual hardware, eg. Raspberry Pi.
A Docker installation can be performed by three commands.
Firstly a Docker image is built where the `openhabian` code is injected (see `tests/Dockerfile.*` for details).

To begin, first make a Docker container for your platform.
An example Docker container build for `amd64` would look like:

``` bash
docker build --tag openhabian/install-openhabian -f tests/Dockerfile.amd64-installation .
```

The container is run by executing:

``` bash
docker run --privileged --rm --name "openhabian-install" -d openhabian/install-openhabian
```

Lastly the installation is invoked by executing:

``` bash
docker exec -i "openhabian-install" bash -c "./build.bash local-test && /boot/first-boot.bash"
```

Be sure to cleanup the tests after you are finished by executing:

``` bash
docker stop openhabian-install
```

Notice that the "Docker system" mimics a hardware SD-card installation with the command `./build.bash local-test`.

### Test Cases
The test cases are further divided into three categories and can be individually invoked by the BATS framework.
The tests' categories can be identified in the naming of the test.
The tests' code are held in a corresponding file to the code itself.
For example, code would reside in `helpers.bash` with tests in `helpers.bats`.

To begin, first make a Docker container for your platform.
An example Docker container build for `amd64` would look like:

``` bash
docker build --tag openhabian/bats-openhabian -f tests/Dockerfile.amd64-BATS .
docker run --rm --name "openhabian-bats" -d openhabian/bats-openhabian
```

Now that we have a functioning Docker container, the categories are as follows:

#### Development Tests `development-<name>`
These tests run first and allow you to test the functionality of code you are actively developing quickly.

``` bash
docker exec -i "openhabian-bats" bash -c 'bats --tap --recursive --filter "development-." .'
```

#### Unit Tests `unit-<name>`
These tests do not alter the host system, the test is executed and is isolated to a specific function.
These tests are not required on an installed base system of openHABian.

``` bash
docker exec -i "openhabian-bats" bash -c 'bats --tap --recursive --filter "unit-." .'
```

#### Installation Verification `installation-<name>`
This is a suite of tests designed to verify a normal installation.
These tests **shall** not alter the base openHABian system.

``` bash
docker exec -i "openhabian-bats" bash -c 'bats --tap --recursive --filter "installation-." .'
```

#### Destructive Verification Tests `destructive-<name>`
These tests install new functionality and are therefore destructive to the openHABian base system.
Typical use-cases are testing of optional packages or a specific configuration of a baseline package.

``` bash
docker exec -i "openhabian-bats" bash -c 'bats --tap --recursive --filter "destructive-." .'
```

### Linter
The ShellCheck linter can be run by using the following commands:

``` bash
shellcheck -x -s bash openhabian-setup.sh
shellcheck -x -s bash functions/*.bash
shellcheck -x -s bash build-image/*.bash
shellcheck -x -s bash build.bash tests/ci-setup.bash
```

To run the ShellCheck tests automatically run:

``` bash
tests/test.bash shellcheck
```

## Community Guidelines

We want to keep the openHAB community awesome, growing and collaborative.
We need your help to keep it that way.
To help with this we've come up with some general guidelines for the community as a whole.
The official guidelines are [located here](https://community.openhab.org/guidelines), the essentials are:

*   Be nice: Be courteous, respectful and polite to fellow community members: no regional, racial, gender, or other abuse will be tolerated.
    We like nice people way better than mean ones!

*   Encourage diversity and participation: Make everyone in our community feel welcome, regardless of their background and the extent of their contributions, and do everything possible to encourage participation in our community.

*   Keep it legal: Basically, don't get us in trouble.
    Share only content that you own, do not share private or sensitive information, and don't break the law.

*   Stay on topic: Make sure that you are posting to the correct channel and avoid off-topic discussions.
    Remember when you update an issue or respond to an email you are potentially sending to a large number of people.
    Please consider this before you update.
    Also remember that nobody likes spam.
