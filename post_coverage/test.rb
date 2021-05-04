require 'octokit'

client = Octokit::Client.new(access_token: ENV["INPUT_ACCESS-TOKEN"])
client.create_check_suite("granluo/issue_generations", "30ef35bc7780dd4e1a947f3b395eeea7d50a7fa3")
print ("asdf")
