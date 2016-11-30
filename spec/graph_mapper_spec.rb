require 'spec_helper'

describe Grom::GraphMapper do
  let(:extended_class) { Class.new { extend Grom::GraphMapper } }

  describe '#create_graph_from_ttl' do
    it 'should create an RDF graph given ttl data in a string format' do
      expect(extended_class.create_graph_from_ttl(PERSON_ONE_TTL).first).to eq PERSON_ONE_GRAPH.first
    end

    it 'should return an RDF graph when there are single quotes in the ttl data' do
      expect(extended_class.create_graph_from_ttl(BUDDY_TTL)).to eq BUDDY_GRAPH
    end
  end

  describe '#get_id' do
    it 'should return the id if given a uri' do
      expect(extended_class.get_id(RDF::URI.new('http://id.example.com/123'))).to eq '123'
    end

    it 'should return "type" if given an RDF.type uri' do
      expect(extended_class.get_id(RDF.type)).to eq 'type'
    end
  end

  describe '#convert_to_ttl' do
    it 'should return a string of ttl given a graph' do
      expect(extended_class.convert_to_ttl(PARTY_ONE_GRAPH)).to eq PARTY_ONE_TTL
    end
  end

  describe '#statements_mapper' do
    it 'should return a hash with the mapped predicates and the respective objects from a graph' do
      arya = extended_class.statements_mapper(PEOPLE_GRAPH).select{ |o| o[:id] == '2' }.first
      expect(arya[:forename]).to eq 'Arya'
      surname_pattern = RDF::Query::Pattern.new(:subject, RDF::URI.new("#{DATA_URI_PREFIX}/schema/surname"), :object)
      expect(arya[:graph].query(surname_pattern).first_object.to_s).to eq 'Stark'
    end
  end

  describe '#get_through_graphs' do
    it 'should return an array of graphs, given a graph and an id' do
      result_arr = extended_class.get_through_graphs(PARTY_MEMBERSHIP_GRAPH, '23')
      start_date_statement = RDF::Statement.new(RDF::URI.new('http://id.example.com/25'), RDF::URI.new('http://id.example.com/schema/partyMembershipStartDate'), RDF::Literal.new("1953-01-12", :datatype => RDF::XSD.date))
      end_date_statement = RDF::Statement.new(RDF::URI.new('http://id.example.com/25'), RDF::URI.new('http://id.example.com/schema/partyMembershipEndDate'), RDF::Literal.new("1954-01-12", :datatype => RDF::XSD.date))
      expect(result_arr[0].has_statement?(start_date_statement)).to be true
      expect(result_arr[0].has_statement?(end_date_statement)).to be true
    end
  end

  describe '#split_by_subject' do
    let(:result) { extended_class.split_by_subject(PARTY_AND_PARTY_MEMBERSHIP_ONE_GRAPH, 'DummyParty') }
    let(:party_type_pattern) { RDF::Query::Pattern.new(RDF::URI.new('http://id.example.com/23'), RDF::URI.new("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"), :object) }
    let(:party_membership_type_pattern) { RDF::Query::Pattern.new(RDF::URI.new('http://id.example.com/25'), RDF::URI.new("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"), :object) }
    let(:party_one_name_pattern) { RDF::Query::Pattern.new(RDF::URI.new('http://id.example.com/23'), RDF::URI.new("#{DATA_URI_PREFIX}/schema/partyName"), :object) }

    it 'should return a hash with the property "associated_class_graph" for the associated property' do
      expect(result[:associated_class_graph].query(party_one_name_pattern).first_object.to_s).to eq 'Targaryens'
    end

    it 'should keep the type statement in the "associated_class_graph"' do
      expect(result[:associated_class_graph].query(party_type_pattern).first_object.to_s).to eq 'http://id.example.com/schema/DummyParty'
    end

    it 'should return a hash with the property "through_graph" for the through property' do
      start_date_pattern = RDF::Query::Pattern.new(RDF::URI.new('http://id.example.com/25'), RDF::URI.new("#{DATA_URI_PREFIX}/schema/partyMembershipStartDate"), :object)
      end_date_pattern = RDF::Query::Pattern.new(RDF::URI.new('http://id.example.com/25'), RDF::URI.new("#{DATA_URI_PREFIX}/schema/partyMembershipEndDate"), :object)
      expect(result[:through_graph].query(start_date_pattern).first_object.to_s).to eq '1953-01-12'
      expect(result[:through_graph].query(end_date_pattern).first_object.to_s).to eq '1954-01-12'
    end

    it 'should not have imported the through type statement from the "associated_graph"' do
      expect(result[:associated_class_graph].query(party_membership_type_pattern).first_object.to_s).to eq ""
    end

    it 'should delete the associated type statement from the "through_graph"' do
      expect(result[:through_graph].query(party_type_pattern).first_object.to_s).to eq ""
    end

    it 'should keep the type statement in the "through_graph"' do
      expect(result[:through_graph].query(party_membership_type_pattern).first_object.to_s).to eq "#{DATA_URI_PREFIX}/schema/DummyPartyMembership"
    end

    it 'should return the associated object id in the "through_graph"' do
      associated_class_pattern = RDF::Query::Pattern.new(RDF::URI.new('http://id.example.com/25'), RDF::URI.new("#{DATA_URI_PREFIX}/schema/partyMembershipHasParty"), :object)
      expect(result[:through_graph].query(associated_class_pattern).first.object.to_s).to eq "#{DATA_URI_PREFIX}/23"
    end
  end
end