class MembersController < ApplicationController
  add_crumb("Members") { |instance| instance.send :members_path }
  
  #filter_access_to :all
  autocomplete_for :member, :emailid, :query => "%%{field} LIKE(%%{query}) AND deleted_at IS NULL", :mask => '%%{value}%%' do |items|
    items.map{|item| "#{item.firstname} #{item.lastname};#{item.emailid}"}.join("\n")
  end

  # GET /members
  # GET /members.xml
  def index
    @center_id = session[:center_id]+""
    if session[:current_user_super_admin]
      @members = Member.find(:all, :order => 'firstname').paginate :page => params[:page], :per_page => 10
    else
      @members = Member.union([{:conditions => ['center_id = ?', session[:center_id]]}, {:conditions => ['id = ?', '33']}], {:order => 'firstname'}).paginate :page => params[:page], :per_page => 10
    end
    @tags = Tag.find(:all,:conditions => ["center_id=?", session[:center_id]])
    @tag_names = []
    @tags.each do |tg|
       @tag_names << tg.name
    end
    @tg = @tag_names.map {|element|
        "'#{element}'"
      }.join(',');
    respond_to do |format|
      format.html # index.html.erb
      format.xml { render :xml => @members }
    end
  end

  def show
    @tags = Tag.find(:all,:conditions => ["center_id=?", session[:center_id]])
    @tag_names = []
    @tags.each do |tg|
       @tag_names << tg.name
    end
    @tg = @tag_names.map {|element|
        "'#{element}'"
      }.join(',');

    begin
      if params["search_by_name"].empty? and params["search_by_email"].empty? and params["search_by_tags"].empty? then
        if session[:current_user_super_admin]
          @members = Member.find(:all,:order => 'firstname').paginate :page => params[:page], :per_page => 10
        else
          @members = Member.union([{:conditions => ['center_id = ?', session[:center_id]]}, {:joins => :communication_subscriptions, :conditions => ['communication_subscriptions.center_id=?', session[:center_id]]}], {:order => 'firstname'}).paginate :page => params[:page], :per_page => 10
        end
      else
            unless params["search_by_name"].empty?
              if session[:current_user_super_admin]
                @members = Member.find(:all,:order => 'firstname',:conditions => ['firstname like ? or lastname like ?', "%"+params["search_by_name"]+"%", "%"+params["search_by_name"]+"%"]).paginate :page => params[:page], :per_page => 10
              else
                @members = Member.union([{:conditions => ['(firstname like ? or lastname like ?) and center_id = ?', "%"+params["search_by_name"]+"%", "%"+params["search_by_name"]+"%", session[:center_id]]}, {:joins => :communication_subscriptions, :conditions => ['(firstname like ? or lastname like ?) and communication_subscriptions.center_id=?', "%"+params["search_by_name"]+"%", "%"+params["search_by_name"]+"%", session[:center_id]]}], {:order => 'firstname'}).paginate :page => params[:page], :per_page => 10
              end
            end
            unless params["search_by_tags"].empty?
              if session[:current_user_super_admin]
                @tag = Tag.find_by_name(params["search_by_tags"])
                @members = Member.find(:all,:order => 'firstname', :joins => :member_taggings, :conditions => ['member_taggings.tag_id = ?', @tag.id]).paginate :page => params[:page], :per_page => 10
              else
                @tag = Tag.find_by_name(params["search_by_tags"])
                @members = Member.union([{:joins => :member_taggings, :conditions => ['member_taggings.tag_id = ? and center_id=?', @tag.id, session[:center_id]]}, {:joins => [:member_taggings,:communication_subscriptions], :conditions => ['member_taggings.tag_id = ? and communication_subscriptions.center_id=?', @tag.id, session[:center_id]]}], {:order => 'firstname'}).paginate :page => params[:page], :per_page => 10
              end
            end
            unless params["search_by_email"].empty?
              if session[:current_user_super_admin]
                @members = Member.find(:all,:order => 'firstname', :conditions => ['emailid like ?', "%"+params["search_by_email"]+"%"]).paginate :page => params[:page], :per_page => 10
              else
                 @members = Member.union([{:conditions => ['emailid like ? and center_id=?', "%"+params["search_by_email"]+"%", session[:center_id]]}, {:joins => :communication_subscriptions, :conditions => ['emailid like ? and communication_subscriptions.center_id=?', "%"+params["search_by_email"]+"%", session[:center_id]]}], {:order => 'firstname'}).paginate :page => params[:page], :per_page => 10
              end
            end
      end
         
      respond_to do |format|
        format.html # show.html.erb
        format.xml  { render :xml => @member }
      end
    end
  end

  # GET /members/new
  # GET /members/new.xml
  def new
    @member = Member.new
    @centers = Center.find(:all)

    @mode = params[:mode]
    @csid = params[:csid]
    @emailid = params[:emailid]
    unless @emailid.nil?
      @member.emailid = @emailid
    end
    unless @mode.nil?
      render :layout => 'signup'
    end
  end

  # GET /members/1/edit
  def edit
    @member = Member.find(params[:id])
  end

  # POST /members
  # POST /members.xml
  def create
    @member = Member.new(params[:member])
    @validatemember = Member.find(:all, :conditions => ["emailid = ?", @member.emailid])
    if @validatemember.length == 0
      @mode = params[:mode]
      if session[:current_user_super_admin] and @mode.blank?
        @member.center_id = params[:centersel][:id]
      else
        @member.center_id = session[:center_id]
      end
      @member.gender = params[:gender]
      if @member.save
        
        if @mode.blank?
          flash[:notice] = 'Member was successfully created.'
          redirect_to params.merge!(:action => "index")
        else
          @csid = params[:csid]
          @member_attendance = MemberAttendance.new
          @member_attendance.member = @member
          @member_attendance.center_id = session[:center_id]
          @member_attendance.course_schedule = CourseSchedule.find(@csid)
          if @member_attendance.save
          end
          redirect_to params.merge!(:controller=>"member_attendances", :action=>"show", :csid => @csid, :emailid => @member.emailid, :name => @member.fullname)
        end
      else
        if params[:mode].nil?
          render :action => "new", :csid => @csid, :mode => params[:mode]
        else
          render :action => "new", :csid => @csid, :mode => params[:mode], :layout => 'signup'
        end
      end
    else
      if params[:mode].nil?
        flash[:notice] = 'Member already Exists.'
        redirect_to params.merge!(:action => "new")
      else
          @csid = params[:csid]
          @member_attendance = MemberAttendance.new
          @member_attendance.member = @member
          @member_attendance.center_id = session[:center_id]
          @member_attendance.course_schedule = CourseSchedule.find(@csid)
          if @member_attendance.save
          end
          redirect_to params.merge!(:controller=>"member_attendances", :action=>"show", :csid => @csid, :emailid => @member.emailid, :name => @member.fullname)
      end
    end

  end

  def save_tags
    puts params[:sel_tags]
    puts params[:mem_id]
    @member = Member.find(params[:mem_id])
    @member.member_taggings.destroy_all
    @sel_tags =params[:sel_tags].split(",")
    @sel_tags.each do |sel_tag|
      @member_tag = MemberTagging.new
      @member_tag.member = @member
      @tag = Tag.find_by_name(sel_tag)
      @member_tag.tag = @tag
      @member_tag.save
    end
    
    respond_to do |format|
      format.html { redirect_to members_path }
      format.js
    end
  end

  def save_notes
    @member = Member.find(params[:mem_id])
    @member_note = MemberNote.new
    @member_note.member = @member
    @member_note.author = session[:user]
    @member_note.note = params[:addednote]
    @member_note.save

    respond_to do |format|
      format.html { redirect_to members_path }
      format.js
    end
  end
  # PUT /members/1
  # PUT /members/1.xml




  def update
    @member = Member.find(params[:id])
    @member.updateby = current_user
    @member.gender = params[:gender]
    if @member.update_attributes(params[:member])
      flash[:notice] = 'Member was successfully updated.'
      redirect_to :action => "index"
    else
      flash[:notice] = 'An error occured updating the member information.'
      redirect_to :action => "index"
    end
  end

  # DELETE /members/1
  # DELETE /members/1.xml
  def destroy
    @member = Member.find(params[:id])
    @member.destroy

    respond_to do |format|
      format.html { redirect_to(members_url) }
      format.xml  { head :ok }
    end
  end

  #   def memberselect
  #    begin
  #     @member = Member.new(params[:member])
  #     @members = Member.find(:all, :conditions => ["firstname = ? OR lastname = ? OR emailid = ?" ,@member.firstname, @member.lastname, @member.emailid])
  #     if @members.length == nil
  #       redirect_to  :controller => "users", :action => "memberselect"
  #     else
  #     end
  #   end
  #  end


  def insert_feedback
    @feedback = MemberGeneralFeedback.new(params[:feedback])
    @member_id = @feedback.member_id

    if @feedback.save
      flash[:notice] = "Your feedback was successfully created"
    else
      flash[:notice] = "Failed to create Feedback"
    end
    @feedbacks = MemberGeneralFeedback.find(:all, :conditions => ["member_id = ?", @member_id])
   
    puts "in insert_feedback"
    puts params[:feedback]
    puts params[:member_id]
     
  end

  def insert_course_interest
    #  puts params[:name]

    @course_interests = MemberCourseInterest.new(params[:membercourseinterest])

    params[:name].each do |a|
      puts "vakdd"
      @course_interests.course_id = a
      puts @course_interests.course_id

      @find_member = MemberCourseInterest.find(:all, :conditions => ["course_id = ?",@course_interests.course_id])
      if @find_member.length == 0
        @course_interests.save
      end
    end
  end
end
 
