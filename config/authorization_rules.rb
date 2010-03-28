authorization do
  role :admin do
    has_permission_on [:user_sessions, :courses, :users, :members, :member_courses, :member_course_interests, :member_general_feedbacks, :course_schedules], :to => [:index, :show, :new, :create, :edit, :update, :destroy]
  end

  role :volunteer do
    has_permission_on [:courses, :members, :member_courses, :member_course_interests, :member_general_feedbacks, :course_schedules], :to => [:index, :show, :new, :create, :edit, :update, :destroy]
    has_permission_on :users, :to => [:edit, :update]
  end

  role :guest do
    has_permission_on :members, :to => [:index, :show]
  end
end
