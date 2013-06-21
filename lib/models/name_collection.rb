module Taxonifi
  class NameCollectionError < StandardError; end
  module Model

    # A collection of taxonomic names. 
    class NameCollection < Taxonifi::Model::Collection

      # A Hash. Keys are the name (String), values are ids of Names in the collection. 
      # { rank => { name => [ids] }}
      # There are two special ranks "genus_group" and "species_group".
      # E.g.: {'species_group' => {'bar' => [1,2,93]}})
      attr_accessor :by_name_index

      # A Taxonifi::Model::RefCollection, optionally generated from Author/Year strings 
      attr_accessor :ref_collection

      # An optional collection of existing combinations of species names, as represented by 
      # individual arrays of Taxonifi::Model::Names.  Note you can not use a Taxonifi::Model::SpeciesName 
      # for this purpose because getting/setting names therin will affect other combinations
      # DEPRECATE? 
      attr_accessor :combinations

      # A Hash. Contains metadata when non-unique names are found in input parsing
      # {unique row identifier => { redundant row identifier => {properties hash}}}
      # TODO: reconsider, move to superclass or down to record base
      # TODO: Test
      attr_accessor :duplicate_entry_buffer

      # A Hash.  An index with keys = Name.id, and values an Array of Arrays, the inner array containing Strings
      # representing the genus, subgenus, species, and subspecies name.
      # Automatically populated when .add_object is used.  Alternately populated with .add_nomenclator(Name)
      # { TaxonName => [[genus_string, subgenus_string, species_string, subspecies_string, infrasubspecific_string (e.g. variety)],...,[]] }
      # !! The names represented in the Array of strings does *NOT* have to be represented in the NameCollection
      attr_accessor :nomenclators

      # TODO!! 
      # [Reference: [ nomenclator_id ] (index)]
      attr_accessor :citations

      def initialize(options = {})
        super 
        @by_name_index = {'genus_group' => {}, 'species_group' => {} }                 # "'Aus bus' => [1,2,3]"
        Taxonifi::RANKS[0..-5].inject(@by_name_index){|hsh, v| hsh.merge!(v => {})}    # Lumping species and genus group names 
        @by_name_index['unknown'] = {}                                                 # unranked names get dumped in here
        @ref_collection = options[:ref_collection]
        @combinations = []  # DEPRECATE?
        @nomenclators = {} 
        @duplicate_entry_buffer = {} # Move to Collection?!
        true
      end 

      def ref_collection=(ref_collection)
        @ref_collection ||= ref_collection
      end

      def object_class
        Taxonifi::Model::Name
      end

      # Return the highest RANK for which there is no
      # name in this collection.
      def encompassing_rank
        highest = RANKS.size
        @collection.each do |n|
          h = RANKS.index(n.rank)
          highest = h if h < highest
        end
        RANKS[highest - 1]
      end 

      # Returns an Array of the names objects in the collection at a rank. 
      # TODO: Should index this on add_object
      def names_at_rank(rank)
        raise if !RANKS.include?(rank)
        names = []
        @collection.each do |n|
          names << n if n.rank == rank
        end
        names
      end

      # Returns id of matching existing name
      # or false if there is no match.
      # !! assumes parent is set
      # Matches against name, year, and all parents (by id).
      # 
      # !! nominotypic names are considered to be the same (species and generic).  See 
      #   @combinations to instantiate these
      #
      # TODO: This is likely already overly ICZN flavoured.
      def name_exists?(name = Taxonifi::Model::Name) 
        # species/genus group names are indexed for indexing purposes 
        rank = name.index_rank

        if by_name_index[rank][name.name_author_year_string]
          by_name_index[rank][name.name_author_year_string].each do |id|
            full_parent_vector = parent_id_vector(name.parent.id) 
            return id if full_parent_vector == parent_id_vector(id)  # this hits species/genus group names

            vector = parent_id_vector(id)
            next if vector.last != name.parent.id                    # can stop looking at this possiblity
            vector.pop                                               # compare just parents
            if vector == full_parent_vector 
              exists = true
              return id
            end
          end
        end 
        false 
      end

      # Add an individual Name instance, indexing it.
      def add_object(obj)
        super
        index_by_name(obj)
        derive_nomenclator(obj) if obj.nomenclator_name?
        obj
      end

      # Add an individaul Name instance, without indexing it. 
      def add_object_pre_indexed(obj)
        super
        index_by_name(obj)
        obj
      end

      # TODO: Test
      def derive_nomenclator(obj)
        if obj.nomenclator_name?
          add_nomenclator(obj.id, obj.nomenclator_array)
        else 
          raise
        end
      end

      # TODO: Test
      def add_nomenclator(id, nomenclator_array)
        if @nomenclators[id]
          @nomenclators[id].push(nomenclator_array) if !@nomenclators[id].include?(nomenclator_array)
        else
          @nomenclators[id] = [nomenclator_array]
        end
        true 
      end

      # Add a Taxonifi::Model::SpeciesName object
      # as individual objects.
      def add_species_name(sn)
        raise "Failed trying to load [#{sn.display_name}]. SpeciesName#genus#parent must be set before using add_species_name." if sn.genus.parent.nil?
        current_parent_id = sn.genus.parent.id 
        sn.names.each do |o|
          o.parent = object_by_id(current_parent_id)
          if id = name_exists?(o)
            cp_id = id 
          else
            add_object(o)
            cp_id = o.id
          end
          current_parent_id = cp_id
        end
        current_parent_id # return the id of the last name created
      end

      # As #add_species_name but do
      # not assign ids to the incoming names
      # TODO: deprecate?
      def add_species_name_unindexed(sn)
        sn.names.each do |o|
          if !name_exists?(o)
            add_object(o)
          end
        end
      end

      # Take the author/years of these names and generate a reference collection.
      # Start the ids assigned to the references with initial_id.
      def generate_ref_collection(initial_id = 0)
        rc = Taxonifi::Model::RefCollection.new(:initial_id => initial_id)
        if collection.size > 0
          uniques = collection.inject({}){|hsh, n| hsh.merge!(n.author_year_string => nil)}.keys.compact
          if  uniques.size > 0
            uniques.sort.each_with_index do |r, i|
              next if r.size == 0
              ref = Taxonifi::Model::Ref.new(:author_year => r)        
              rc.add_object(ref)
            end
          end
        end
        @ref_collection = rc 
      end

      # Assign a reference collection to this name collection. 
      # !! Overwrites existing reference collection, including ones built
      # using generate_ref_collection. 
      def ref_collection=(ref_collection)
        @ref_collection = ref_collection if ref_collection.class == Taxonifi::Model::RefCollection
      end

      # Return an Array of "homonyms" within the rank
      # provided.  Useful for finding missmatched upper heirarchies,
      # if nc is a name_collection:
      #
      #  homonyms = nc.homonyms_at_rank('genus')
      #  homonyms.keys.sort.each do |n|
      #    puts "#{n} (#{homonyms[n].size}) :"
      #    homonyms[n].each do |p|
      #      puts "  #{p.ancestors.collect{|i| i.name}.join(",")}"
      #    end
      #  end 
      #
      def homonyms_at_rank(rank) 
        raise if !RANKS.include?(rank)
        uniques = {}
        names_at_rank(rank).each do |n|
          uniques.merge!(n.name => []) if !uniques[n.name]
          uniques[n.name].push n
        end
        uniques.delete_if{|k| uniques[k].size < 2}
        uniques
      end

      # Add a record to @duplicate_entry_buffer
      def add_duplicate_entry_metadata(name_id, row_identifier, data_hash)
        @duplicate_entry_buffer[name_id] = Hash.new if !@duplicate_entry_buffer[name_id]
        @duplicate_entry_buffer[name_id].merge!(row_identifier => data_hash)
      end
      

      # Return an Array of Strings
      def genus_group_name_strings
        by_name_index['genus_group'].keys
      end

      # Return an Array of Strings
      def species_group_name_strings
        by_name_index['species_group'].keys
      end

      # Return an array of the names in the collection
      # DEPRECATE for name_strings
      def name_string_array
        collection.collect{|n| n.display_name}
      end 


      protected

      # Index the object by name into the @by_name_index variable 
      # Pass a Taxonifi::Name
      def index_by_name(name)
        rank = name.rank
        rank = 'species_group' if %w{species subspecies variety}.include?(rank)
        rank = 'genus_group' if %w{genus subgenus}.include?(rank)
        rank ||= 'unknown'

        by_name_index[rank][name.name_author_year_string] ||= [] 
        by_name_index[rank][name.name_author_year_string].push name.id 
      end
    end

  end
end
