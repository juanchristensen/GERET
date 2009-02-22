
require 'lib/mapper_types'
include Mapper

module Abnf
  
  class Parser
    Slot = Struct.new( :name, :rule, :end )
   
    def initialize
      @transitions = {
        :start =>    {
                       :symbol => proc {|g,t| g.rule=t; :equals },
                       :newline => proc { :start },
                       :comment => proc { :start }
                     },
        :equals =>   {
                       :equals => proc { :elements },
                       :eq_slash => proc {|g,t| g.retype=:incremental; :elements },
                       :comment => proc { :equals },  
                       :space => proc { :equals } 
                     },
        :elements => {
                       :symbol => proc {|g,t| g.tok=t; :elements },
                       :literal => proc {|g,t| g.tok=t; :elements },
                       :_digit => proc {|g,t| g.ranges(t,['0'..'9']); :elements },
                       :_hexdig => proc {|g,t| g.ranges(t,['0'..'9','A'..'F']); :elements },
                       :_bit => proc {|g,t| g.ranges(t,['0'..'1']); :elements },
                       :_alpha => proc {|g,t| g.ranges(t,['A'..'Z','a'..'z']); :elements },
                       :_char => proc {|g,t| g.ranges(t,[0x01..0x7F]); :elements },
                       :_vchar => proc {|g,t| g.ranges(t,[0x21..0x7E]); :elements },                      
                       :_octet => proc {|g,t| g.ranges(t,[0x00..0xFF]); :elements },
                       :_ctl => proc {|g,t| g.ranges(t,[0x00..0x1F,0x7F..0x7F]); :elements },
                       :_wsp => proc {|g,t| g.ranges(t,[' '..' ',"\t".."\t"]); :elements },                      
                       :_cr => proc {|g,t| g.entity="\r"; :elements },
                       :_lf => proc {|g,t| g.entity="\n"; :elements },
                       :_crlf => proc {|g,t| g.entity="\r\n"; :elements },
                       :_sp => proc {|g,t| g.entity=" "; :elements },
                       :_dquote => proc {|g,t| g.entity=%Q("); :elements },
                       :_htab => proc {|g,t| g.entity="\t"; :elements },
                       :slash =>  proc {|g,t| g.alt; :elements },
                       :newline => proc {|g,t| :next_rule },
                       :seq_begin => proc {|g,t| g.group=t; :elements },
                       :seq_end => proc {|g,t| g.store=t; :elements },                    
                       :opt_begin => proc {|g,t| g.opt=t; :elements },
                       :opt_end => proc {|g,t| g.store=t; :elements },                    
                       :comment => proc { :elements },  
                       :space => proc { :elements },
                       :number => proc {|g,t| g.repeat=t.data; :rpt_1 },
                       :asterisk => proc { |g,t| g.repeat=0; :rpt_2 },
                       :eof => proc { |g,t| g.retype=:eof; g.store=t; :stop }                    
                     },
        :rpt_1 =>    {
                        :number => proc {|g,t| g.repeat=t.data; :rpt_1 },
                        :asterisk => proc { :rpt_2 },
                        :symbol => proc {|g,t| g.tok=t; :elements },
                        :literal => proc {|g,t| g.tok=t; :elements },
                        :_digit => proc {|g,t| g.ranges(t,['0'..'9']); :elements },
                        :_hexdig => proc {|g,t| g.ranges(t,['0'..'9','A'..'F']); :elements },
                        :_bit => proc {|g,t| g.ranges(t,['0'..'1']); :elements },
                        :_alpha => proc {|g,t| g.ranges(t,['A'..'Z','a'..'z']); :elements },
                        :_char => proc {|g,t| g.ranges(t,[0x01..0x7F]); :elements },
                        :_vchar => proc {|g,t| g.ranges(t,[0x21..0x7E]); :elements },
                        :_octet => proc {|g,t| g.ranges(t,[0x00..0xFF]); :elements },
                        :_ctl => proc {|g,t| g.ranges(t,[0x00..0x1F,0x7F..0x7F]); :elements },
                        :_wsp => proc {|g,t| g.ranges(t,[' '..' ','\t'..'\t']); :elements },
                        :_cr => proc {|g,t| g.entity="\r"; :elements },
                        :_lf => proc {|g,t| g.entity="\n"; :elements },
                        :_crlf => proc {|g,t| g.entity="\r\n"; :elements },
                        :_sp => proc {|g,t| g.entity=" "; :elements },
                        :_htab => proc {|g,t| g.entity="\t"; :elements },
                        :_dquote => proc {|g,t| g.entity=%Q("); :elements },                       
                        :seq_begin => proc {|g,t| g.group=t; :elements },
                        :space => proc { :rpt_1 },
                     },
        :rpt_2 =>    {
                        :number => proc {|g,t| g.repeat=t.data; :elements },
                        :space => proc { :rpt_2 },
                     },
        :next_rule => {
                       :symbol => proc {|g,t|  g.store=t; g.rule=t; :equals },
                       :comment => proc { :next_rule },                      
                       :space => proc { :elements },
                       :newline => proc { :next_rule },
                       :eof => proc { |g,t| g.retype=:eof; g.store=t; :stop }
                      },
      }

    end

    def parse stream
      @stack = []
      @iv = 0
      @repeat_range = [] 
      @range_rules = []    
      @gram = Grammar.new 
      state = :start
 
      stream.each do |token|
        trans = @transitions.fetch state
        action = trans.fetch( token.type, nil )
        raise "Parser: unexpected token '#{token.type}' when in #{state}" if action.nil?
        state = action.call( self, token )
      end
      @gram
    end

    def Parser.check_symbols grammar
      undefs = []
      defs = grammar.keys
      grammar.each_value do |rule|
        rule.each do |alt|
          alt.each do |token| 
            next unless token.type == :symbol
            next if defs.include? token.data 
            undefs.push token.data 
          end
        end
      end
      undefs
    end
    
    protected
    
    def rule=( token )
      @stack.push Slot.new( token.data, Rule.new, :symbol )
      alt
    end

    def retype=( arg )
      @stack.last.end = arg if @stack.last.end == :symbol  
    end

    def group=( token )
      name = @stack.last.name + "_grp#{@iv+=1}"
      self.tok = Token.new( :symbol, name ) 
      @stack.push Slot.new( name, Rule.new, :seq_end )
      alt
    end

    def opt=( token )
      name = @stack.last.name + "_opt#{@iv+=1}"
      self.tok = Token.new( :symbol, name ) 
      @stack.push Slot.new( name, Rule.new, :opt_end )
      alt
      @stack.last.rule.last.push Token.new( :literal, '' ) # not self.tok 
      alt
    end
    
    def alt
      @stack.last.rule.push RuleAlt.new
    end

    def repeat=( data )
      @repeat_range.push data.to_i 
    end

    def ranges( token, ranges )
      name = token.type.to_s

      unless @range_rules.include? name 
        rule = Rule.new 
        ranges.each do |rng|
          rng.each do |i| 
            alt = RuleAlt.new      
            data = ""
            data << i
            alt.push Token.new( :literal, data ) 
            rule.push alt
          end
        end
        @gram[ name ] = rule
        @range_rules.push name
      end
      
      self.tok = Token.new( :symbol, name )      
    end

    def entity=( str )
      self.tok = Token.new( :literal, str )
    end

    def tok=( token )

      unless @repeat_range.empty?
        raise "Parser: max. allowed number of repetitions exceeded" if @repeat_range.last > 64
        raise "Parser: min>max in repetition" if @repeat_range.first > @repeat_range.last
        name = @stack.last.name + "_rpt#{@iv+=1}"
        rule = Rule.new
        for i in @repeat_range.first .. @repeat_range.last
          alt = RuleAlt.new
          i.times { alt.push token }
          alt.push Token.new( :literal, '' ) if i==0
          rule.push alt
        end
        @gram[ name ] = rule
        token = Token.new( :symbol, name )
        @repeat_range = []
      end
      
      @stack.last.rule.last.push token

    end

    def store=( token )
      slot = @stack.pop
      case slot.end
      when :incremental
        orig_rule = @gram.fetch( slot.name, nil )
        raise "Parser: incremental alternative: '#{slot.name}' must be defined first" if orig_rule.nil?
        orig_rule.concat slot.rule
      when token.type
        orig_rule = @gram.fetch( slot.name, nil ) 
        raise "Parser: symbol '#{slot.name}' already defined" unless orig_rule.nil?
        @gram[ slot.name ] = slot.rule
      else
        raise "Parser: missing '#{slot.end}' token"
      end
    end
  end

end




