
include Selection

class Generational

  attr_accessor :termination, :population_size, :elite_size, :crossover_probability, :mutation_probability

  def initialize
  end

  def setup config
    @cfg = config
    @store = @cfg.factory('store')
    @grammar = @cfg.factory('grammar')
    @mapper = @cfg.factory('mapper', @grammar)
    @selection = @cfg['selection_rank'].nil? ? 
                 @cfg.factory('selection') : 
                 @cfg.factory('selection', @cfg.factory('selection_rank') ) 
    @elite_rank = @cfg.factory('elite_rank')     
    @crossover = @cfg.factory('crossover')
    @mutation = @cfg.factory('mutation')   
    @report = @cfg.factory('report')

    @cfg.factory( 'individual', @mapper ) #todo: because of require
    @population = @store.load
    @population = [] if @population.nil?
    while @population.size < @population_size
      individual = @cfg.factory( 'individual', @mapper )
      @population << individual if individual.valid? 
    end

    @steps = 0

    return @report    
  end

  def teardown
    puts "--------- finished:"
    @store.save @population
    return @report   
  end

  def step
    puts "--------- step #{@steps += 1}" 

    ranked_population = ( @elite_rank.rank @population ).map { |ranked| ranked.original }
    @report.report ranked_population
       
    new_population = ranked_population[0...@elite_size]  
       
    @selection.population = @population  
    while new_population.size < @population_size
      if rand < @crossover_probability 
        parents = @selection.select 2 
        chromozome, dummy = @crossover.crossover( parents.first.genotype, parents.last.genotype ) 
      else
        #chromozome = @selection.select_one.genotype 
        chromozome = @cfg.factory( 'individual', @mapper ).genotype
      end
   
      chromozome = @mutation.mutation chromozome if rand < @mutation_probability  
      
      individual = @cfg.factory( 'individual', @mapper, chromozome ) 
      new_population << individual if individual.valid?
    end

    @population = new_population

    return @report
  end

  def finished?
    if ( ! @termination['max_steps'].nil? and @steps >= @termination['max_steps'] ) or
       ( ! @termination['on_individual'].nil? and @population.detect { |individual| individual.send @termination['on_individual'] } )
 
      ranked_population = ( @elite_rank.rank @population ).map { |ranked| ranked.original }
      @report.report ranked_population

      return true
    end
    return false
  end

end

