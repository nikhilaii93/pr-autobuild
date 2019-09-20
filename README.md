# pr-autobuild #
> Automatically builds & merges a PR and deletes PR branches if they satisfies configurable approval criteria.

<p align="left">
  <a href="https://github.com/nikhilaii93/pr-autobuild"><img alt="GitHub Actions status" src="https://github.com/nikhilaii93/pr-autobuild/workflows/Shell%20Check/badge.svg"></a>
</p>

## Worflows supported ##
### PR Build Trigger ###
1. Configure this workflow to trigger PR build if the PR satisfies criteria:
	1. Mandatory: Approval count is greater than equal to **DEFAULT_APPROVAL_COUNT_ENV** variable
	1. Mandatory: There is no review iwth **changes_requested** status
	1. Optional: PR is tagged with a certain label **PR_LABEL_ENV**
1. The workflow gets triggered in the following scenarios:
	1. When PR review is submitted
	1. When PR is labeled
	1. Note: build will only be triggered if PR satisfies the above criteria and is independent of the event that triggered the workflow in the first place
1. Currently, build through Github Actions is not supported
1. Build can be triggered if using [GitHub pull request builder plugin](https://wiki.jenkins.io/display/JENKINS/GitHub+pull+request+builder+plugin)
	1. The action can trigger build using trigger phrase
	1. Configure the trigger phrase using **BUILD_COMMENT_ENV**
1. You need to provide GIT token and user name to action so that it has access to the GIT APIs
	1. Create **token** with read & comment permission on issues, [follow here](https://github.blog/2013-05-16-personal-api-tokens/)
	1. Add **token** as **secret** using [this guide](https://help.github.com/en/articles/virtual-environments-for-github-actions#creating-and-using-secrets-encrypted-variables)
	1. In the sample worflow the secret name is **bot_token**
1. Trigger PR build sample workflow:
```
name: PR Auto-build

on:
  pull_request:
    types: [labeled]
  pull_request_review:
    types: [submitted]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger pr-autobuild action for building PR
        uses: nikhilaii93/pr-autobuild@master
        env:
          GITHUB_TOKEN: ${{ secrets.bot_token }}
          GITHUB_NAME: nikhilaii93
          DEFAULT_APPROVAL_COUNT_ENV: 1
          BUILD_COMMENT_ENV: "OK to test"
          PR_LABEL_ENV: RELEASE_TEST
```

### PR Merge & Delete branch ###
1. PR is merged when it's **mergeable** according to **branch protection rules**
1. The following are still verified (in case branch protection rules are not set)
	1. Mandatory: Approval count is greater than equal to **DEFAULT_APPROVAL_COUNT_ENV** variable
	1. Mandatory: There is no review iwth **changes_requested** status
	1. Optional: PR is tagged with a certain label **PR_LABEL_ENV**
	1. Optional: Build is successful (eg. through Jenkins)
1. This workflow gets triggered through a external event which is a POST call:
```
curl -s -X POST -u nikhilaii93:$TOKEN -H "Content-Type: application/json" -H "Accept: application/vnd.github.everest-preview+json" "https://api.github.com/repos/$GITHUB_REOSITORY/dispatches" -d '{"event_type": "pr-build-success $PR_NUM"}'
```
	1. Replace **$TOKEN** with actual GITHUB access token
	1. Replace **$GITHUB_REPOSITORY** with owner/repo
	1. Replace **$PR_NUM** with actual PR number
1. The above event can be triggered through Jenkins on build success
1. PR Name in GitHub pull request builder plugin can be obtained through **ghprbPullId** environment variable
1. The PR is merge method used is based on the following logic:
	1. If base or head branch is named **release** then default merge is used **always**
	1. If **DEFAULT_MERGE_ENV** is set to **merge** or not set at all then 'default merge' is used for other PRs as well
	1. If **DEFAULT_MERGE_ENV** is set to squash then **squash merge** is used (if base or head is not named release)
1. This flow can also delete the branch after merge
	1. It deletes if delete is enabled using **DELETE_BRANCH_ENV** has been set to true
	1. It only delete when the associated PR has been merged
1. Trigger PR Merge sample workflow:

```
name: PR Auto-merge

on: repository_dispatch

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger pr-autobuild action
        uses: nikhilaii93/pr-autobuild@master
        env:
          GITHUB_TOKEN: ${{ secrets.bot_token }}
          GITHUB_NAME: nikhilaii93
          DEFAULT_APPROVAL_COUNT_ENV: 1
          BUILD_COMMENT_ENV: "OK to test"
          PR_LABEL_ENV: RELEASE
          DEFAULT_MERGE: squash
          DELETE_BRANCH_ENV: true
```

## Contributing

If you have suggestions for how rubberneck could be improved, or want to report a bug, open an issue! We'd love all and any contributions.

For more, check out the [Contributing Guide](CONTRIBUTING.md).

## License

[ISC](LICENSE) © 2019 Nikhil Verma <nikhilverma.ajm@gmail.com>