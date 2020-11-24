# frozen_string_literal: true

require 'octokit'
require 'optparse'
require "json"

pp ENV
REPO_NAME_WITH_OWNER = ENV['GITHUB_REPOSITORY']
NO_WORKFLOW_RUNNING_INFO = 'All nightly cron job were not run. Please make sure there at least exists one cron job running.'.freeze
EXCLUDED_WORKFLOWS = []
ISSUE_LABELS = ""
ISSUE_TITLE = "Auto-Generated Testing Report"

if not ENV['INPUT_EXCLUDE-WORKFLOW-FILES'].nil?
  EXCLUDED_WORKFLOWS = ENV['INPUT_EXCLUDE-WORKFLOW-FILES'].split(/[ ,]/)
end
if not ENV['INPUT_ISSUE-LABELS'].nil?
  ISSUE_LABELS = ENV['INPUT_ISSUE-LABELS']
end
if not ENV['INPUT_ISSUE-TITLE'].nil?
  ISSUE_TITLE = ENV['INPUT_ISSUE-TITLE']
end
ASSIGNEE = ENV['INPUT_ASSIGNEES']

class Table
  def initialize(title)
    cur_time = Time.now.utc.localtime("-08:00")
    @is_empty_table = true
    @text = String.new ""
    @text << "# %s\n" % [title]
    @text << "This issue is generated at %s\n" % [cur_time.strftime('%m/%d/%Y %H:%M %p %:z') ]
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

failure_report = Table.new(ISSUE_TITLE)
success_report = Table.new(ISSUE_TITLE)
client = Octokit::Client.new(access_token: ENV["INPUT_ACCESS-TOKEN"])
last_issue = client.list_issues(REPO_NAME_WITH_OWNER, :labels => ISSUE_LABELS, :state => "all")[0]
workflows = client.workflows(REPO_NAME_WITH_OWNER)

puts "Excluded workflow files: " + EXCLUDED_WORKFLOWS.join(",")
for wf in workflows.workflows do
  # skip if it is the issue generation workflow.
  if wf.name == ENV["GITHUB_WORKFLOW"]
    next
  end
  workflow_file = File.basename(wf.path)
  puts workflow_file
  workflow_text = "[%s](%s)" % [wf.name, wf.html_url]
  runs = client.workflow_runs(REPO_NAME_WITH_OWNER, File.basename(wf.path), :event => "schedule").workflow_runs 
  runs = runs.sort_by { |run| -run.created_at.to_i }
  latest_run = runs[0]
  if latest_run.nil?
    puts "no schedule runs found."
  elsif EXCLUDED_WORKFLOWS.include?(workflow_file)
    puts workflow_file + " is excluded in the report."
  elsif Time.now.utc - latest_run.created_at < 86400
    result_text = "[%s](%s)" % [latest_run.conclusion.nil? ? "in_process" : latest_run.conclusion, latest_run.html_url]
    if latest_run.conclusion == "success"
      success_report.add_workflow_run_and_result(workflow_text, result_text)
    else
      failure_report.add_workflow_run_and_result(workflow_text, result_text)
    end
  end
end

# Check if there exists any cron jobs.
if failure_report.get_report.nil? && success_report.get_report.nil?
  if last_issue.state == "open"
    client.add_comment(REPO_NAME_WITH_OWNER, last_issue.number, NO_WORKFLOW_RUNNING_INFO)
  else
    client.create_issue(REPO_NAME_WITH_OWNER, ISSUE_TITLE, NO_WORKFLOW_RUNNING_INFO, labels: ISSUE_LABELS, assignee: ASSIGNEE)
  end
# Close an issue if all workflows succeed.
elsif failure_report.get_report.nil? and last_issue.state == "open"
  client.add_comment(REPO_NAME_WITH_OWNER, last_issue.number, success_report.get_report)
  client.close_issue(REPO_NAME_WITH_OWNER, last_issue.number)
# If the last issue is open, then failed report will be commented to the issue.
elsif !last_issue.nil? and last_issue.state == "open"
  client.add_comment(REPO_NAME_WITH_OWNER, last_issue.number,failure_report.get_report)
  last_issue.add_comment(REPO_NAME_WITH_OWNER, last_issue.number,failure_report.get_report)
# Creat an new issue otherwise.
else
  client.create_issue(REPO_NAME_WITH_OWNER, ISSUE_TITLE, failure_report.get_report, labels: ISSUE_LABELS, assignee: ASSIGNEE)
end
