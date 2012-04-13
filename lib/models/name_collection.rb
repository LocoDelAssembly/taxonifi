module Taxonifi
  module Model

    class NameCollection
      attr_accessor :names
      def initialize(options = {})
        @names = []
        true
      end 

      def add_name(name)
        raise if !(name.class == Taxonifi::Model::Name)
        @names.push(name)
      end

      # The highest RANKS for which there is no
      # name.
      def encompassing_rank
        highest = RANKS.size
        @names.each do |n|
          h = RANKS.index(n.rank)
          highest = h if h < highest
        end
        RANKS[highest - 1]
      end 

      # Should index this on add_name
      def names_at_rank(rank)
        raise if !RANKS.include?(rank)
        names = []
        @names.each do |n|
          names << n if n.rank == rank
        end
        names
      end


    end
  end

end
