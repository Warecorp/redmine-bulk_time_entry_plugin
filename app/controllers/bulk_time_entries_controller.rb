class BulkTimeEntriesController < ApplicationController
  unloadable
  layout 'base'
  before_action :load_activities
  before_action :load_allowed_projects
  before_action :load_first_project
  before_action :check_for_no_projects

  helper :custom_fields
  include BulkTimeEntriesHelper

  protect_from_forgery :only => [:index, :save]

  def index
    @time_entries = [TimeEntry.new(:spent_on => today_with_time_zone.to_s)]
  end

  def load_assigned_issues
    @issues = get_issues(params[:project_id])
    @selected_project = BulkTimeEntriesController.allowed_project?(params[:project_id])
    respond_to do |format|
      format.js {}
    end
  end


  def save
    if request.post?
      @unsaved_entries = {}
      @saved_entries = {}

      params.to_unsafe_h[:time_entries].each_pair do |html_id, entry|
        time_entry = TimeEntry.create_bulk_time_entry(entry)
        if time_entry.new_record?
          @unsaved_entries[html_id] = time_entry
        else
          @saved_entries[html_id] = time_entry
        end
      end

      respond_to do |format|
        format.js {}
      end
    end
  end

  def add_entry
    begin
      spent_on = Date.parse(params[:date]).next if params[:date].present?
    rescue ArgumentError
      # Fall through
    end
    spent_on ||= today_with_time_zone

    hours = params[:hours].present? ? params[:hours].to_i : 0

    @time_entry = TimeEntry.new(spent_on: spent_on.to_s, hours: hours.to_f)
    @first_project = Project.find params[:project_id].to_i if params[:project_id].present?
    @selected_issue = params[:issue_id].to_i if params[:issue_id].present?
    @selected_activity = params[:activity_id].to_i if params[:activity_id].present?

    respond_to do |format|
      format.js {}
    end
  end

  private

  def load_activities
    @activities = TimeEntryActivity.all
  end

  def load_allowed_projects
    @projects = User.current.projects.where(
      Project.allowed_to_condition(User.current, :log_time))
  end

  def load_first_project
    @first_project = @projects.sort_by(&:lft).first unless @projects.empty?
  end

  def check_for_no_projects
    if @projects.empty?
      render :action => 'no_projects'
      return false
    end
  end

  # Returns the today's date using the User's time_zone
  #
  # @return [Date] today
  def today_with_time_zone
    time_proxy = Time.zone = User.current.time_zone
    time_proxy ||= Time # In case the user has no time_zone
    today = time_proxy.now.to_date
  end

  def self.allowed_project?(project_id)
    return User.current.projects.where(Project.allowed_to_condition(User.current, :log_time)).
                                 where(id: project_id).first
  end
end
