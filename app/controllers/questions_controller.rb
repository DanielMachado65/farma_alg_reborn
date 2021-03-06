class QuestionsController < ApplicationController
  load_and_authorize_resource

  include AnswerLanguageExtension

  before_action :authenticate_user!
  before_action :find_question, only: [:show, :edit, :update, :destroy]
  before_action :find_exercise, only: [:index, :new, :create]
  before_action :find_exercise_questions, only: [:new, :create, :edit, :update]
  before_action :find_dependencies, only: [:edit, :update]

  def index
    @questions = Question.where(exercise: @exercise)
                         .paginate(page: params[:page], per_page: 5)
  end

  def new
    @question = Question.new
  end

  def create
    @question = @exercise.questions.build(question_params)
    if @question.save
      @questions.each do |question|
        operator = dependency_operator(question)
        QuestionDependency.create!(question_1: @question, question_2: question,
                                   operator: operator) unless operator.empty?
      end

      flash[:success] = "Questão criada e adicionada ao exercício!"
      redirect_to @question
    else
      render 'new'
    end
  end

  def show
    @answer = Answer.new
    @answer.lang_extension = answer_language_extension(@question)
    @submitable = true
  end

  def edit
  end

  def update
    if @question.update_attributes(question_params)
      @questions.each do |question|
        dependency = @dependencies.where(question_2: question).first
        operator = dependency_operator(question)
        # If dependency doesn't exists.
        if dependency.nil?
          QuestionDependency.create!(question_1: @question, question_2: question,
                                     operator: operator) unless operator.empty?
        else
          # The ""(empty) option points that the dependency must be removed.
          if operator.empty?
            dependency.destroy
          else
            # Update only if the operator changed
            dependency.update_attributes(operator: operator) if operator != dependency.operator
          end
        end
      end

      flash[:success] = "Questão atualizada!"
      redirect_to @question
    else
      render 'edit'
    end
  end

  def destroy
    exercise = @question.exercise
    @question.destroy
    flash[:success] = "Questão excluída!"
    redirect_to exercise_questions_url(exercise)
  end

  def test_answer
    @answer = @question.answers.build(answer_params)
    @answer.lang_extension = answer_language_extension(@question)
    creator = AnswerCreator::Creator.new(@answer)
    @answer.correct = creator.correct?
    @results = creator.test_cases_results

    respond_to { |format| format.js { render 'shared/test_answer' } }
  end

    private

    # If @exercise is nil, the method is called from 'edit'/'update' action, so
    # the @question already exists and should not be returned (doesn't make
    # sence the option of create a dependency whit the question itself).
    def find_exercise_questions
      if @exercise.nil?
        @questions = Question.where("exercise_id = ? AND id != ?",
                                    @question.exercise, @question.id)
      else
        @questions = Question.where(exercise: @exercise)
      end
    end

    def question_params
      params.require(:question)
        .permit(
          :title,
          :description,
          :exercise_id,
          :operation,
          :score,
          :answer_language_allowed
        )
    end

    def answer_params
      params.require(:answer).permit(:content)
    end

    def find_question
      @question = Question.find(params[:id])
    end

    def find_exercise
      @exercise = Exercise.find(params[:exercise_id])
    end

    def find_dependencies
      @dependencies = @question.question_dependencies
    end

    # Get the operator sended to the question in the form.
    def dependency_operator(question)
      params["question-#{question.id}"] || ""
    end
end
