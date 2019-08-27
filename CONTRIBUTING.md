## Contribution Guidelines

### Pull Requests are Always Welcome

We are always thrilled to receive pull requests, and do our best to process them as fast as possible.
Not sure if that typo is worth a pull request? Do it! We will appreciate it.

If your pull request is not accepted on the first try, don't be discouraged!
If there's a problem with the implementation, you will receive feedback on what to improve.

We might decide against incorporating a new feature that does not match the scope of this project.
Get in contact early in the development to propose your idea.

### Workflow Making Changes

Fork the repository and make changes on your fork in a feature branch.

Update the documentation when creating or modifying features.
Test your documentation changes for clarity, concision, and correctness, as well as a clean documentation build.

Write clean, modular and testable code.
We have a codestyle which in combination the static linter Shellcheck works as guidelines.

Pull requests descriptions should be as clear as possible and include a reference to all the issues that they address.

Pull requests must not contain commits from other users or branches.

Commit messages must start with a capitalized and short summary (max. 50 chars) written in the imperative, followed by an optional, more detailed explanatory text which is separated from the summary by an empty line. [See here for more details.](http://chris.beams.io/posts/git-commit)

Code review comments may be added to your pull request.
Discuss, then make the suggested modifications and push additional commits to your feature branch.
Be sure to post a comment after pushing.
The new commits will show up in the pull request automatically, but the reviewers will not be notified unless you comment.

Pull request will be tested on CI platform which shall pass. 
Please provide test-cases for new features. See testing below. 

Before the pull request is merged, your commits might get squashed, based on the size and style of your contribution.
Include documentation changes in the same pull request, so that a revert would remove all traces of the feature or fix.

Commits that fix or close a GitHub issue should include a reference like `Closes #XXX` or `Fixes #XXX`, which will automatically close the issue when merged.

### Sign-off your Work

The sign-off is a simple line at the end of the explanation for the patch, which certifies that you wrote it or otherwise have the right to pass it on as an open-source patch.
If you can certify the below (from [developercertificate.org](http://developercertificate.org)):

```
Developer Certificate of Origin Version 1.1

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

then you just add a line to the end of every git commit message:

```text
Signed-off-by: Joe Smith <joe.smith@email.com> (github: github_handle)
```

using your real name (sorry, no pseudonyms or anonymous contributions.)

If your commit contains code from others as well, please ensure that they certify the DCO as well and add them with an "Also-By" line to your commit message:

```text
Also-by: Ted Nerd <ted.nerd@email.com> (github: github_handle_ted)
Also-by: Sue Walker <sue.walker@email.com> (github: github_handle_sue)
Signed-off-by: Joe Smith <joe.smith@email.com> (github: github_handle_joe)
```

#### Small Patch Exception

There are several exceptions to the sign-off requirement.
Currently these are:

* Your patch fixes spelling or grammar errors.
* Your patch is a single line change to documentation.

### Sign your Work using GPG

You can additionally sign your contribution using GPG.
Have a look at the [git documentation](https://git-scm.com/book/tr/v2/Git-Tools-Signing-Your-Work) for more details.
This step is optional and not needed for the acceptance of your pull request.

#### Codestyle

Universally formatted code promotes ease of writing, reading, and maintenance.

## Community Guidelines

We want to keep the openHAB community awesome, growing and collaborative.
We need your help to keep it that way.
To help with this we've come up with some general guidelines for the community as a whole:

* **Be nice:**
Be courteous, respectful and polite to fellow community members:
no regional, racial, gender, or other abuse will be tolerated.
We like nice people way better than mean ones!

* **Encourage diversity and participation:**
Make everyone in our community feel welcome, regardless of their background and the extent of their contributions.
Do everything possible to encourage participation in our community.

* **Keep it legal:**
Basically, don't get us in trouble.
Share only content that you own, do not share private or sensitive information, and don't break the law.

* **Stay on topic:**
Make sure that you are posting to the correct channel and avoid off-topic discussions.
Remember when you update an issue or respond to an email you are potentially sending to a large number of people.
Please consider this before you update.
Also remember that nobody likes spam.


## Code Guidelines

* Use two (2) spaces when indent code.

* `local` declerations of variables shall be used when possible.

### Usage of `apt-get update` command

To minimize unnecessary updates of the local apt database running `apt-get update` is only permitted in:

1) Once in the `first-boot.bash` file prior to installing the system first time.

2) Once when the `openhabian-config.sh` script is invoked.

3) When new repository sources are added by installation scripts.

## Test Architecture

Testing is based on three pilars: A) *Installation of base system*, B) *Test Cases*, and C) *Static analys using linter*.

### Test installation
Test installation are done continuously using a Docker on a Travis Virtual Machine and by testing on actual hardware, eg. Raspberry Pi. A docker installation can be performed by three commands. Firstly a docker image is built where the `openhabian` code is injected (see `dockerfile` for details): 

```
docker build --tag openhabian/openhabian-bats .
```
The openhabian scripts is using `systemd` for service management, to use `systemd` with docker it must the container must be started first to ensure `systemd` gets pid 1. This is done by executing:

```
docker run --name "install-test" --privileged -d openhabian/openhabian-bats
```
Lastly the installation is invoked by executing:
```
docker exec -it install-test bash -c "./build.bash local-test && mv ~/.profile ~/.bash_profil && /etc/rc.local"
```
Notice that the "docker system" mimic a hardware SD-card installation with the command `./build.bash local-test`. 

### Test Cases
The test cases are further divided into three categories and can be individual invoked by the BATS framwork. The tests categary can be identified in the naming of the test. The test code are held in a corresponding file to the code itself, i.e. Code: `helpers.bash` and tests `helpers.bats`. The categories are as follows:

#### Unit Tests `unit-<name>`
These test does not alter the host system where the test is executed and is isolated to a specific function. This test does not required a installed base system of openHABian.
```
docker run -it openhabian/openhabian-bats bash -c 'bats -r -f "unit-." .' 
```

#### Installation Verification `installation-<name>`
This is a suite of tests designed to verify a normal installation.
These tests shall not alter the system. 
```
docker exec -it install-test bash -c 'bats -r -f "installation-." .'
```


#### Destructive Verification Tests `destruct-<name>`
These test installs new functionality and are therefore destruct for the current system. Typical usecase are testing of optional packages or a specific configuration of a baseline package.
```
docker exec -it install-test bash -c 'bats -r -f "destructive-." .'
```

### Linter

```
shellcheck -s bash openhabian-setup.sh
shellcheck -s bash functions/*.bash
shellcheck -s bash build-image/*.bash
```