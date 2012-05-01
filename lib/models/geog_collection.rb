module Taxonifi
  class GeogCollectionError < StandardError; end

  module Model

    class GeogCollection < Taxonifi::Model::Collection
    
      attr_accessor :row_index

      def initialize(options = {})
        super
        @row_index = []
        true
      end 

      def object_class
        Taxonifi::Model::Geog
      end
         
      def object_from_row(row_number)
        @row_index[row_number]
      end

    end
  end

end