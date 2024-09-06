class HabitsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_habit, only: %i[show edit update destroy]

  # GET /habits or /habits.json
  def index
    @habits = Habit.all
    @habit = Habit.new  # @habitを新しく定義してエラーを防ぐ
    @weekly_plan = params[:weekly_plan] || []
  end

  # GET /habits/1 or /habits/1.json
  def show
    @habit = Habit.find(params[:id])
  end

  # GET /habits/new
  def new
    @habit = Habit.new
  end

  # GET /habits/1/edit
  def edit
  end

  # POST /habits or /habits.json
  def create
    @habit = current_user.habits.new(habit_params)
    if @habit.save
      # 週間目標を計算
      @weekly_plan = calculate_habit_plan(
        @habit.target_date,
        @habit.target_frequency,
        @habit.target_volume_hours.to_i * 60 + @habit.target_volume_minutes.to_i
      )
      
      # WeeklyPlanテーブルに保存
      @weekly_plan.each do |plan|
        WeeklyPlan.create!(
          habit: @habit,
          week: plan[:week],
          frequency: plan[:frequency],
          volume: plan[:volume]
        )
      end
      
      # 週間目標を表示するためのビューにリダイレクト
      redirect_to habits_path, notice: '習慣目標が保存されました。'
    else
      render :new
    end
  end

  # PATCH/PUT /habits/1 or /habits/1.json
  def update
    respond_to do |format|
      if @habit.update(habit_params)
        format.html { redirect_to habit_url(@habit), notice: "Habit was successfully updated." }
        format.json { render :show, status: :ok, location: @habit }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @habit.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /habits/1 or /habits/1.json
  # app/controllers/habits_controller.rb
  def destroy
    @habit.destroy!

    respond_to do |format|
      format.html { redirect_to habits_url, notice: '習慣が削除されました。' }
      format.json { head :no_content }
    end
  end


  private

  # Use callbacks to share common setup or constraints between actions.
  def set_habit
    @habit = Habit.find(params[:id])
  end

  def habit_params
    params.require(:habit).permit(:name, :target_date, :target_frequency, :target_volume_hours, :target_volume_minutes)
  end

  def calculate_habit_plan(target_date, target_frequency, target_volume_minutes)
    target_volume_minutes ||= 0 # volumeがnilの場合に0をデフォルトとする
  
    today = Date.today
    total_days = (target_date - today).to_i
    total_weeks = (total_days / 7.0).ceil
  
    weekly_frequencies = Array.new(total_weeks) do |i|
      (target_frequency.to_f / total_weeks * (i + 1)).round
    end
  
    weekly_volumes = Array.new(total_weeks) do |i|
      (target_volume_minutes.to_f / total_weeks * (i + 1)).round
    end
  
    weekly_volumes = weekly_volumes.map { |volume| (volume / 15.0).ceil * 15 }
  
    total_allocated_volume = weekly_volumes.sum
    if total_allocated_volume > target_volume_minutes
      weekly_volumes[-1] -= (total_allocated_volume - target_volume_minutes)
    elsif total_allocated_volume < target_volume_minutes
      weekly_volumes[-1] += (target_volume_minutes - total_allocated_volume)
    end
  
    weekly_plan = total_weeks.times.map do |i|
      {
        week: i + 1,
        frequency: weekly_frequencies[i] || weekly_frequencies.last,
        volume: weekly_volumes[i] || weekly_volumes.last
      }
    end
  
    weekly_plan
  end
  
end
