require 'utils/middlerizer'

module IncentiveRanking
  class Builder
    def initialize(target:, team:, answers_number: 5, positions: {})
      @target = target
      @team = team
      @positions = positions
      @answers_number = answers_number
    end

    def build
      ranking_data = UserScoreQuery.new.ranking(team: @team)
      return [] if ranking_data.empty?
      ranking = middlerized_incentive_ranking_object(ranking_data)

      ranking = IncentiveRanking::GhostUser::Applier.new(
        incentive_ranking: ranking,
        team: @team,
        ghost_users_number: @positions[:below]
      ).apply

      ranking.to_array
    end

    private

    def format_ranking(ranking)
      formated_ranking = []

      ranking.lower_half.each { |user_score|
        formated_ranking << user_score_hash(user_score)
      }

      middle = user_score_hash(ranking.middle)
      formated_ranking << middle

      ranking.upper_half.each { |user_score|
        formated_ranking << user_score_hash(user_score)
      }

      Middlerizer.new(middle: middle, array: formated_ranking)
    end

    def join_ranking_with_answers!(ranking)
      [:upper_half, :lower_half].each do |half|
        ranking.send(half).each { |user_score|
          user_score.merge!(answers: select_answers(user_score[:user]))
        }
      end

      ranking.middle.merge!(answers: select_answers(ranking.middle[:user]))

      ranking
    end

    def select_answers(user)
      Answer.where(user: user, team: @team)
      .limit(@answers_number)
      .order(created_at: :desc)
    end

    def user_score_hash(user_score)
      { user: user_score.user, score: user_score.score }
    end

    def middlerized_incentive_ranking_object(ranking_data)
      ranking = Middlerizer.new(
        middle: ranking_data.by_user(@target).first,
        array: ranking_data,
        limits: { upper: @positions[:above], lower: @positions[:below] }
      )

      formated_ranking = format_ranking(ranking)
      join_ranking_with_answers!(formated_ranking)
    end
  end
end
