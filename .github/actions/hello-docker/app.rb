# frozen_string_literal: true

require 'octokit'
require 'optparse'
require "functions_framework"
require "json"
require "google/cloud/firestore"
require 'net/http'

# This function receives an HTTP request of type Rack::Request
# and interprets the body as JSON. It prints the contents of
# the "message" field, or "Hello World!" if there isn't one.
FunctionsFramework.http "hello_world" do |request|
  input = JSON.parse request.body.read rescue {}
  puts input
  job_ID = input["job_ID"].to_s
  generate_issue = input["generate_issue"].to_s.downcase
  if job_ID.empty? && generate_issue != "true"
    return "Either workflow or job_ID should not be empty."
  end

  GITHUB_TOKEN='1454422f8a491e134f75427e600c114c28aef29f'
  FAILED_WORKFLOW_LINK='https://github.com/firebase/firebase-ios-sdk/actions/runs/'
  WORKFLOW_LINK='https://github.com/firebase/firebase-ios-sdk/actions?query=workflow%3A'
  PROJECT_ID='firebase-ios-issue-test'
  WORKFLOW_INTERVAL = 86400
  DAYS_OF_LOGS = 5
  
  client = Octokit::Client.new(access_token: GITHUB_TOKEN)
  
  #296975925
  
  text = File.read("template.md")
  text = text.gsub("TEST_ISSUE_TITLE", "Nightly testing report." )
  text = text.gsub("TEST_WORKFLOW", "Workflows")
  # text = text.gsub("WORKFLOW_LINK", options.getFailedLink)
  # text = text.gsub("FAILED_JOBS", options.jobs.map{ |job| " - " + job}.join("\n") )

  cur_time = Time.now.utc.localtime("-07:00")

  text << "This issue is generated at %s\n" % [cur_time.strftime('%m/%d/%Y %H:%M %p') ]
  text << "| Workflow |"
  for day in 1..DAYS_OF_LOGS do
    text << (cur_time - (day - 1) * 86400).strftime('%m/%d') + "|"
  end 
  text << "\n| -------- |"
  for day in 1..DAYS_OF_LOGS do
    text << " -------- |"
  end 
  text << "\n"
  

  nightly_test_status = "success"

  
  
  REPO_NAME_WITH_OWNER = 'granluo/issue_generations'.freeze
  SDK_REPO = 'firebase/firebase-ios-sdk'.freeze
  
  if generate_issue == "true"
    # new_issue = client.create_issue(REPO_NAME_WITH_OWNER, 'Failure detected in workflow %s' % [options.workflow], text, labels: ['octokit-test'])
    # p new_issue.url
    firestore = Google::Cloud::Firestore.new project_id: 'firebase-ios-testing'
    puts "Created Cloud Firestore client with given project ID."
    workflows_ref = firestore.doc "firebase-issue-test/ios"
    workflows_ref.cols do |wf|
      workflow = client.workflow(SDK_REPO, wf.collection_id + ".yml")
      log_url = WORKFLOW_LINK + workflow.name
      days_before_now = 0
      workflow_conclusion = ""
      workflow_text = String.new ""
      workflow_text << "[%s](%s)" % [workflow.name, workflow.html_url] + "|"
      until days_before_now == DAYS_OF_LOGS do
        start_time = cur_time - (days_before_now + 1) * 86400
        end_time = cur_time - days_before_now * 86400
        query = wf.where("time", "<", end_time).where("time", ">", start_time).order("time", "desc").limit(1)
        if query.get.first.nil?
          # TODO: Add report generator.
          result = "Not Found"
        else 
          query.get do |job_run_rec|
            # https://developer.github.com/v3/actions/workflow-runs/#get-a-workflow-run
            job_run = client.workflow_run(SDK_REPO, job_run_rec.data[:job_ID].to_s)
            # https://developer.github.com/v3/actions/workflows/#get-a-workflow
            uri = URI(job_run.workflow_url)
            response = Net::HTTP.get(uri)
            workflow_data = JSON.parse(response)
            # result = (Time.now - job_run.created_at > WORKFLOW_INTERVAL ) ?  "broken" : job_run.conclusion
            result = job_run.conclusion
            log_url = job_run.html_url
            # text << "|" + "[%s](%s)" % [workflow_data["name"], workflow_data["html_url"]] + "|" + "[%s](%s)" % [result, job_run.html_url]+ "|" + (job_run.created_at + Time.zone_offset("PDT")).strftime('%m/%d/%Y %H:%M %p') + "|\n" 
            
            # text << "[%s](%s)" % [result, job_run.html_url]+ "|"# + (job_run.created_at + Time.zone_offset("PDT")).strftime('%m/%d/%Y %H:%M %p') + "|"
            # text <<  "#{wf.collection_id} : #{job_run_rec.document_id} data: #{job_run_rec.data}}.\n"
          end
        end
        if days_before_now == 0
          workflow_conclusion = result
          result == "success" ? break : nightly_test_status = "failed"
        end
        workflow_text << "[%s](%s)" % [result, log_url]+ "|"# + (job_run.created_at + Time.zone_offset("PDT")).strftime('%m/%d/%Y %H:%M %p') + "|"
        days_before_now += 1
      end

      text << workflow_text+ "(%s)" % [result] + "\n" unless workflow_conclusion == "success"

    end
    if nightly_test_status == "failed"
      if workflows_ref.get[:last_status] == "failed"
        client.add_comment(REPO_NAME_WITH_OWNER, workflows_ref.get[:last_issue_id], text)
      else
        new_issue = client.create_issue(REPO_NAME_WITH_OWNER, 'Nightly Testing Report', text, labels: ['octokit-test'], assignee: 'granluo')
        workflows_ref.update(
          last_issue_id: new_issue.number
        )
      end
    end
    
    workflows_ref.update(
      last_status: nightly_test_status,
      time:  cur_time
    )
    text
    #new_issue.url

#     text = File.read("template.md")
#     text << "|" + workflow + "|" + "[Link](%s)" % [options.workflow]+ "|\n" 
#     job_run = client.workflow_run(SDK_REPO, job_ID)
#     p job_run.url
#     puts "conclusion:\n"
#     p job_run.conclusion
#     puts "status:\n"
#     p job_run.status
  else
    firestore = Google::Cloud::Firestore.new project_id: 'firebase-ios-testing'
    puts "Created Cloud Firestore client with given project ID."
    # https://developer.github.com/v3/actions/workflow-runs/#get-a-workflow-run
    job_run = client.workflow_run(SDK_REPO, job_ID)
    # https://developer.github.com/v3/actions/workflows/#get-a-workflow
    uri = URI(job_run.workflow_url)
    response = Net::HTTP.get(uri)
    workflow_data = JSON.parse(response)
    col_ref = firestore.col "firebase-issue-test/ios/#{workflow_data["name"]}"
    doc_ref = col_ref.add
    doc_ref.set(
      job_ID: job_ID,
      time:  job_run.created_at#Time.now.getutc
    )
    p "complete uploading workflow run record."
  end
end

#GITHUB_TOKEN='695e71a0598c6724d963f33a88671609666fc99f'
#GITHUB_TOKEN='1454422f8a491e134f75427e600c114c28aef29f'
#GITHUB_TOKEN='5023c5a2f5d158a957ef9f4041f7505aee999399'
#GITHUB_TOKEN='1d95f4b4d680e937987334ebc0d109d4a39ff039'
pp ENV
puts "-------"
pp ARGV
#puts "::add-mask::" + ENV["INPUT_ACCESS_TOKEN"]
#REPO_NAME_WITH_OWNER = 'granluo/issue_generations'.freeze
REPO_NAME_WITH_OWNER = 'firebase/firebase-ios-sdk'.freeze
client = Octokit::Client.new(access_token: ENV["INPUT_ACCESS-TOKEN"])
#client = Octokit::Client.new(access_token: GITHUB_TOKEN)
puts client.workflows(REPO_NAME_WITH_OWNER).total_count
#puts client.workflows(REPO_NAME_WITH_OWNER).workflows
#puts client.workflows(REPO_NAME_WITH_OWNER).workflows[0]
# puts client.workflows(REPO_NAME_WITH_OWNER).workflows[0].path
# puts client.workflow_runs(REPO_NAME_WITH_OWNER, 'main.yml', :event => "push").workflow_runs[0].event
# puts client.workflow_runs(REPO_NAME_WITH_OWNER, 'main.yml').workflow_runs[0].event
t1 = Time.now
workflows = client.workflows(REPO_NAME_WITH_OWNER)
text = File.read("/myapp/template.md")
text = text.gsub("TEST_ISSUE_TITLE", "Nightly testing report." )
text = text.gsub("TEST_WORKFLOW", "Workflows")

cur_time = Time.now.utc.localtime("-07:00")

text << "This issue is generated at %s\n" % [cur_time.strftime('%m/%d/%Y %H:%M %p') ]
text << "| Workflow |"
text << (cur_time - 86400).strftime('%m/%d') + "|"
text << "\n| -------- |"
text << " -------- |"
text << "\n"

excluded_workflows = ENV['INPUT_EXCLUDE-WORKFLOW-FILES']
for wf in workflows.workflows do
  workflow_file = File.basename(wf.path)
  puts workflow_file
  workflow_text = String.new ""
  workflow_text << "[%s](%s)" % [wf.name, wf.html_url] + "|"
  runs = client.workflow_runs(REPO_NAME_WITH_OWNER, File.basename(wf.path), :event => "schedule").workflow_runs 
  runs = runs.sort_by { |run| -run.created_at.to_i }
  #puts runs[0].event + runs[0].url + " " + runs[0].created_at.to_s#, run.created_at#, t1 - run.created_at < 86400
  latest_run = runs[0]
  if latest_run.nil?
    puts "no schedule runs found."
  else
    puts latest_run.event + latest_run.html_url + " " + latest_run.created_at.to_s + " " + latest_run.conclusion#, run.created_at#, t1 - run.created_at < 86400
    workflow_text << "[%s](%s)" % [latest_run.conclusion, latest_run.html_url]+ "|"
    text << workflow_text + "\n" unless latest_run.conclusion == "success" && !excluded_workflows.include?(workflow_file)
  end
  for run in runs do
    #puts run.event + run.url + " " + run.created_at.to_s#, run.created_at#, t1 - run.created_at < 86400
  end
end

new_issue = client.create_issue('granluo/issue_generations', 'Nightly Testing Report' + Time.now.utc.localtime("-07:00").strftime('%m/%d/%Y %H:%M %p'), text, labels: [ENV['INPUT_ISSUE-LABEL']], assignee: 'granluo')
