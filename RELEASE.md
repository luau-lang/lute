# Release Process

Lute uses branches with the format: `release/v{Major}.{Minor}.x` to store
changes associated with a given release. We tag commits on these branches with
the format `v{Major}.{Minor}.{Patch}` to indicate that a commit should be build
as that release version. These release branches exist so that we can continue to
support older versions of lute according to some currently unknown SLA, but
continue development on the primary branch. Release notes must be written
manually.

## Working on release branches
As much as possible, we should avoid manually making changes to release
branches, and prefer to develop directly to primary. If changes need to be
applied to release branches (security vulnerabilities or hotfixes), we should
cherry-pick those in as appropriate, only applying changes manually as a last
resort.

## Cutting a release
Cutting a release should be mostly automatic. Navigate to
github.com/luau-lang/lute > actions > release. For this action, select a release
branch from the dropdown to cut the release from - it should start with
`release/v{Major}.{Minor}.x`. 

This job will:
1) Checkout the branch `release/v{Major}.{Minor}.x`.
2) Ensure that this branch passes all status checks
3) Derive a tag in the format `v{Major}.{Minor}.{Patch}`
4) Build `lute` for a bunch of different platforms
5) Create a draft release with the artifacts built in 4)

You should add patch notes for this release manually.

## Nightly releases
Nightlies can be scheduled or triggered manually. Patch notes will be
automatically generated for nightlies.


