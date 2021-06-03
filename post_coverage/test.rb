require 'octokit'

client = Octokit::Client.new(access_token: ENV["INPUT_ACCESS_TOKEN"])
#client.add_comment(REPO_NAME_WITH_OWNER, last_issue.number, NO_WORKFLOW_RUNNING_INFO)
client.create_pull_request_comment("granluo/issue_generations",98,"testing","e35ac3de3cf8c0f5ec95736cd7566a1f144afe18","post_coverage/test.rb",4, {:side=>"RIGHT", :start_line=> 3, :line=> 5})
print ("asdf")
