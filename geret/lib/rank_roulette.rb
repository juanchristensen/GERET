
require 'lib/roulette'

module Selection

  class RankRoulette < Roulette

    def initialize ranker
      raise "RankRoulette: invalid Ranking object" unless ranker.kind_of? Ranking     
      @ranker = ranker
      super :proportion
    end

    def select_one population
      super( @ranker.rank( population ) ).original
    end

  end

end


