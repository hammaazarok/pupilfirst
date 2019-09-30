class ReviewedSubmissionsResolver < ApplicationResolver
  attr_accessor :course_id
  attr_accessor :level_id

  def reviewed_submissions
    submissions.evaluated_by_faculty.includes(:startup_feedback, founders: :user, target: :target_group).order("created_at DESC")
  end

  def authorized?
    return false if current_user.faculty.blank?

    course.in?(current_user.faculty.courses_with_dashboard)
  end

  def course
    @course ||= Course.find(course_id)
  end

  def submissions
    if level_id.present?
      course.levels.where(id: level_id).first.timeline_events
    else
      course.timeline_events
    end
  end
end
