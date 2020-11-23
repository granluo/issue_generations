# frozen_string_literal: true

require 'octokit'
require 'optparse'
require "json"


#GITHUB_TOKEN='695e71a0598c6724d963f33a88671609666fc99f'
#GITHUB_TOKEN='1454422f8a491e134f75427e600c114c28aef29f'
#GITHUB_TOKEN='5023c5a2f5d158a957ef9f4041f7505aee999399'
GITHUB_TOKEN= 'd6c2a737bd7f91b15c46f771cdee558c183fc23d'
pp ENV
puts "-------"
pp ARGV
#puts "::add-mask::" + ENV["INPUT_ACCESS_TOKEN"]
#REPO_NAME_WITH_OWNER = 'granluo/issue_generations'.freeze
client = Octokit::Client.new(access_token: GITHUB_TOKEN)
REPO_NAME_WITH_OWNER = 'firebase/firebase-ios-sdk'.freeze
last_issue = client.list_issues('granluo/issue_generations', :labels => 'asdf')[0]
runs = client.workflow_runs('granluo/issue_generations', 'main.yml', :event => "none").workflow_runs 
if not runs.nil?
  puts '---'
  puts runs
  puts runs[9]
end
if not last_issue.nil? && true
  puts "The last issue id is "
  puts last_issue.id
end
runs = client.workflow_runs(REPO_NAME_WITH_OWNER, "release.yml", :event => "schedule").workflow_runs 

puts runs[0].created_at
cur_time = Time.now.utc
puts cur_time - runs[0].created_at
puts cur_time.strftime('%m/%d/%Y %H:%M %p')
puts Time.now.utc.localtime("-07:00").strftime('%m/%d/%Y %H:%M %p')
