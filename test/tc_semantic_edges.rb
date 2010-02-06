#!/usr/bin/ruby

require 'test/unit'
require 'lib/grammar'
require 'lib/semantic_edges'

include Semantic
include Mapper

class TC_SemanticEdges < Test::Unit::TestCase

  def test_is_executable
    edge = AttrEdge.new( [] )
    assert_equal( true, edge.is_executable? )
    edge = AttrEdge.new( [ 3, 'rr', 4.5, [] ] )
    assert_equal( true, edge.is_executable? )
    edge = AttrEdge.new( [ 3, 'rr', AttrKey.new(0,0), [] ] )
    assert_equal( false, edge.is_executable? )   
  end

  def test_exec
    p = proc {|_| (_.map {|x| x.to_s }).join ' ' }
    edge = AttrEdge.new( [ 3, 'rr', 4.5 ], nil, p )   
    assert_equal( '3 rr 4.5', edge.exec_func )
     
    edge.dependencies = ['foo','bar']
    assert_equal( 'foo bar', edge.exec_func )   

    # check is not needed?
    # edge.dependencies << AttrKey.new(0,0)
    # exception = assert_raise( RuntimeError ) { edge.exec_func }
    # assert_equal( "Semantic::AttrEdge is_executable? check fails", exception.message )
  end

  def test_tokens_to_keys # transform AttrRef->AttrKey using incoming tokens
    target = AttrRef.new( 2, 2 )
    args = [ AttrRef.new( 1, 0 ), AttrRef.new( 0, 3 ) ]
    function = proc { |_| _ }
    attr_fn = AttrFn.new( function, target, args )
    parent_token = Token.new( :symbol, 'expr' )
    child1 = Token.new( :literal, 'immediate_text' )
    child2 = Token.new( :symbol, 'x' )
    child_tokens = [ child1, child2 ]
    
    edge = AttrEdge.create( parent_token, child_tokens, attr_fn )
    
    assert( edge.kind_of? AttrEdge )
    assert_equal( 2, edge.dependencies.size )
    assert_equal( 'immediate_text', edge.dependencies.first ) # attr_idx = 0 is implicitly 'text'
    assert_equal( AttrKey.new( parent_token.object_id, 3 ), edge.dependencies.last )   
    assert_equal( AttrKey.new( child2.object_id, 2 ), edge.result )
    assert_equal( function.object_id, edge.func.object_id )
  end

  def test_substitute_dependencies # by real attrs' values
     
    #edge = AttrEdge.new( dependencies )

    # edge.substitute_deps( attr_hash )
  end

  def test_reduce_batch 
    # try execute whole batch, produce results, 
    # new_results_hash = Edges.reduce_batch( batch, attr_hash )
  end

  def test_reduce_pending
    # new_results_hash = edges.reduce( attr_hash )
  end

  def test_prune_by_age
#    edges.prune_newer( age )
  end

end



