# frozen_string_literal: true

require 'octokit'
require 'optparse'
require "json"

pp ENV
REPO_NAME_WITH_OWNER = 'firebase/firebase-ios-sdk'.freeze
REPORT_TESTING_REPO = 'granluo/issue_generations'.freeze
excluded_workflows = []
issue_labels = ""
issue_title = "Auto-Generated Testing Report"

if not ENV['INPUT_EXCLUDE-WORKFLOW-FILES'].nil?
  excluded_workflows = ENV['INPUT_EXCLUDE-WORKFLOW-FILES'].split(/[ ,]/)
end
if not ENV['INPUT_ISSUE-LABELS'].nil?
  issue_labels = ENV['INPUT_ISSUE-LABELS']
end
if not ENV['INPUT_ISSUE-TITLE'].nil?
  issue_title = ENV['INPUT_ISSUE-TITLE']
end
assignee = ENV['INPUT_ASSIGNEES']

class Table
  def initialize(title)
    cur_time = Time.now.utc.localtime("-08:00")
    @is_empty_table = true
    @text = String.new ""
    @text << "# %s\n" % [title]
    @text << "Failures are detected in workflow(s)\n"
    @text << "This issue is generated at %s\n" % [cur_time.strftime('%m/%d/%Y %H:%M %p') ]
    @text << "| Workflow |"
    @text << (cur_time - 86400).strftime('%m/%d') + "|"
    @text << "\n| -------- |"
    @text << " -------- |"
    @text << "\n"
  end 

  def add_workflow_run_and_result(workflow, result)
    @is_empty_table = false
    record = "| %s | %s |\n" % [workflow, result]
    @text << record
  end 

  def get_report()
    if @is_empty_table
      return nil
    end
    return @text
  end 
end 

failure_report = Table.new(issue_title)
success_report = Table.new(issue_title)
client = Octokit::Client.new(access_token: ENV["INPUT_ACCESS-TOKEN"])
last_issue = client.list_issues(REPORT_TESTING_REPO, :labels => issue_labels, :state => "all")[0]
workflows = client.workflows(REPO_NAME_WITH_OWNER)

puts "Excluded workflow files: " + excluded_workflows.join(",")
for wf in workflows.workflows do
  workflow_file = File.basename(wf.path)
  puts workflow_file
  workflow_text = "[%s](%s)" % [wf.name, wf.html_url]
  runs = client.workflow_runs(REPO_NAME_WITH_OWNER, File.basename(wf.path), :event => "schedule").workflow_runs 
  runs = runs.sort_by { |run| -run.created_at.to_i }
  latest_run = runs[0]
  if latest_run.nil?
    puts "no schedule runs found."
  elsif excluded_workflows.include?(workflow_file)
    puts workflow_file + " is excluded in the report."
  elsif Time.now.utc - latest_run.created_at < 86400
    puts latest_run.event + " "
    puts latest_run.html_url + " "
    puts latest_run.created_at.to_s + " "
    puts latest_run.conclusion
    result_text = "[%s](%s)" % [latest_run.conclusion.nil? ? "in_process" : latest_run.conclusion, latest_run.html_url]
    if latest_run.conclusion == "success"
      success_report.add_workflow_run_and_result(workflow_text, result_text)
    else
      # failure_report.add_workflow_run_and_result(workflow_text, result_text)
    end
  end
end

puts "issue %s is currently %s" % [last_issue.number, last_issue.state]
if failure_report.get_report.nil? && success_report.get_report.nil?
  if last_issue.state == "open"
    client.add_comment(REPORT_TESTING_REPO, last_issue.number, "Nightly Testings were not run.")
  else
    client.create_issue(REPORT_TESTING_REPO, issue_title, "Nightly Testing Report", "Nightly Testings were not run.", labels: issue_labels, assignee: assignee)
  end
elsif failure_report.get_report.nil? and last_issue.state == "open"
  client.add_comment(REPORT_TESTING_REPO, last_issue.number, success_report.get_report)
  client.close_issue(REPORT_TESTING_REPO, last_issue.number)
elsif !last_issue.nil? and last_issue.state == "open"
  puts last_issue.number
  client.add_comment(REPORT_TESTING_REPO, last_issue.number,failure_report.get_report)
  last_issue.add_comment(REPORT_TESTING_REPO, last_issue.number,failure_report.get_report)
else
  new_issue = client.create_issue(REPORT_TESTING_REPO, 'Nightly Testing Report' + Time.now.utc.localtime("-08:00").strftime('%m/%d/%Y %H:%M %p'), failure_report.get_report, labels: issue_labels, assignee: assignee)
end
