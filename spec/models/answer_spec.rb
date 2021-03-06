require 'rails_helper'

RSpec.describe Answer, type: :model do
  describe "Validations" do
    let(:answer) { build(:answer) }

    it "is valid with valid attributes" do
      expect(answer).to be_valid
    end

    it "is invalid with empty content" do
      answer.content = ""
      expect(answer).to_not be_valid
    end

    it "is invalid with empty correct flag" do
      answer.correct = ""
      expect(answer).to_not be_valid
    end

    it "is invalid with empty lang_extension" do
      answer.lang_extension = ""
      expect(answer).to_not be_valid
    end
  end

  describe "Relationships" do
    it "belongs to user" do
      expect(relationship_type(Answer, :user)).to eq(:belongs_to)
    end

    it "belongs to question" do
      expect(relationship_type(Answer, :question)).to eq(:belongs_to)
    end

    it "belongs to team" do
      expect(relationship_type(Answer, :team)).to eq(:belongs_to)
    end

    it "has many test cases results" do
      expect(relationship_type(Answer, :test_cases_results)).to eq(:has_many)
    end

    it "has many connections" do
      expect(relationship_type(Answer, :answer_connections_1)).to eq(:has_many)
      expect(relationship_type(Answer, :answer_connections_2)).to eq(:has_many)
    end
  end

  describe ".created_last" do
    before do
      today = Time.now
      2.times { |i| create(:answer, created_at: today + i.day) }
    end

    it "returns data ordered by time creation" do
      received = Answer.created_last
      expect(received.first.created_at > received.last.created_at).to be_truthy
    end
  end

  describe ".correct_status" do
    let(:answers) { Answer.all }

    before do
      create(:answer)
      create(:answer, :correct)
    end

    context "when status is passed" do
      it "returns the correct data" do
        [true, false].each do |status|
          expect(Answer.correct_status(status)).to eq(answers.where(correct: status))
        end
      end
    end
  end

  describe ".between_dates" do
    let(:start_date) { '2017-01-01' }
    let(:end_date) { '2017-01-02' }
    let!(:answer_1) { create(:answer, created_at: start_date) }
    let!(:answer_2) { create(:answer, created_at: end_date) }

    before { create(:answer, created_at: answer_2.created_at + 1.day) }

    context "when arguments are informed" do
      it "returns the answers in the date range" do
        expected = [answer_1, answer_2]
        expect(Answer.between_dates(start_date, end_date).to_a).to eq(expected)
      end
    end

    context "when aruments aren't informed" do
      it "returns all answers" do
        expect(Answer.between_dates(nil, nil)).to eq(Answer.all)
      end
    end
  end

  describe ".by_key_words" do
    let!(:to_return) { create(:answer, content: "This test should return") }

    before do
      create(:answer, content: "This not")
      Answer.reindex
    end

    it "returns the right answer" do
      expect(Answer.by_key_words("test").to_a).to eq([to_return])
    end
  end

  describe '#similar_answers' do
    let(:answer_1) { create(:answer) }
    let(:answer_2) { create(:answer) }
    let(:answer_3) { create(:answer) }
    let(:answer_4) { create(:answer) }

    let!(:connection_1) { create(:answer_connection, answer_1: answer_2,
                                 answer_2: answer_1, similarity: 10) }
    let!(:connection_2) { create(:answer_connection, answer_1: answer_3,
                                 answer_2: answer_1, similarity: 20) }
    let!(:connection_3) { create(:answer_connection, answer_1: answer_1,
                                answer_2: answer_4, similarity: 20) }

    it "respects the specified threshold" do
      received = answer_1.similar_answers(threshold: 11)
      received_ids = received.map { |obj| obj[:answer].id }

      expect(received.count).to eq(2)
      expect(received_ids).to include(answer_3.id, answer_4.id)
    end

    it "returns the right keys and values" do
      sample_record = answer_1.similar_answers(threshold: 11).first
      keys = sample_record.keys

      expect(keys.count).to eq(3)
      expect(keys).to include(:answer, :connection_id, :similarity)
      expect(sample_record[:answer]).to eq(answer_4)
      expect(sample_record[:connection_id]).to eq(connection_3.id)
      expect(sample_record[:similarity]).to eq(connection_3.similarity)
    end
  end

  describe '#similarity_with' do
    let(:answer_1) { create(:answer) }
    let(:answer_2) { create(:answer) }

    subject { answer_1.similarity_with(answer_2) }

    context "when similarity wasn't calculated yet" do
      it { is_expected.to be_nil }
    end

    context "when similarity was calculated" do
      let!(:connection) {
        create(:answer_connection, answer_1: answer_1, answer_2: answer_2) }

      it { is_expected.to eq(connection.similarity) }
    end
  end

    private

    def create_or_build_right_answer(operation)
      test_case = create(:test_case, output: "Hello, world.\n")
      send(operation, :answer, :whit_custom_callbacks, :hello_world,
           question: test_case.question)
    end

    def create_or_build_wrong_answer(operation)
      test_case = create(:test_case, output: "this should not match")
      send(operation, :answer, :whit_custom_callbacks, :hello_world,
           question: test_case.question)
    end
end
