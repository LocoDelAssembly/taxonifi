require 'helper'
require File.expand_path(File.join(File.dirname(__FILE__), '../lib/assessor/assessor')) 

class Test_TaxonifiAccessor < Test::Unit::TestCase

  def setup
    @headers = ["family", "genus", "species", "author", "year"]
    @csv_string = CSV.generate() do |csv|
      csv <<  @headers
      csv << ["Fooidae", "Foo", "bar", "Smith", "1854"]
    end

    @csv = CSV.parse(@csv_string, {headers: true})
  end

  def test_first_available
    assert_equal [:family, 'Fooidae'], Taxonifi::Assessor::RowAssessor.first_available(@csv.first, [:family, :genus])
  end

  def test_last_available
    assert_equal [:genus, 'Foo'], Taxonifi::Assessor::RowAssessor.last_available(@csv.first, [:family, :genus])
  end

  def test_lump_rank
    assert_equal :species, Taxonifi::Assessor::RowAssessor.lump_rank(@csv.first)
    @csv << ["Fooidae"]
    assert_equal :family, Taxonifi::Assessor::RowAssessor.lump_rank(@csv[1])
    @csv << ["Fooidae", "Blorf"] 
    assert_equal :genus, Taxonifi::Assessor::RowAssessor.lump_rank(@csv[2])
  end

  def test_lump_rank_parent
    assert_equal ["genus", "Foo"], Taxonifi::Assessor::RowAssessor.parent_taxon_column(@csv.first)
  end

end 
