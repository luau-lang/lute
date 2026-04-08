# Release Process

Lute uses branches with the format: `release/v{Major}.{Minor}.x` to store changes associated with a given release.
We tag commits with the format `v{Major}.{Minor}.{Patch}` to indicate that a commit should be build as that release version.
Changes like security updates, hotfixes, etc, occur on these branches and go through the code review process in order to be merged.
These release branches exist so that we can continue to support older versions of lute according to some currently unknown SLA, but continue
development on the mainline branch. Release notes must be cut manually.


## Cutting a release
Cutting a release should be mostly automatic. Navigate to github.com/luau-lang/lute > actions > release. For this action, select a release branch 
from the dropdown to cut the release from - it should start with `release/v{Major}.{Minor}.x`. 

This job will:
1) Checkout the branch `release/v{Major}.{Minor}.x`.
2) Ensure that this branch passes all status checks
3) Derive a tag in the format `v{Major}.{Minor}.{Patch}`
4) Build `lute` for a bunch of different platforms
5) Create a draft release with the artifacts built in 4)

You should add patch notes for this release manually.

## Nightly releases
Nightlies can be scheduled or triggered manually. Patch notes will be automatically generated for nightlies.


