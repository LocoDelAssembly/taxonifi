# Define groups of columns/fields and include
# functionality to determine whether your
# columns match a given set.


module Taxonifi
  module Lumper 

    class LumperError < StandardError; end

    QUAD =  ['genus', 'subgenus', 'species', 'subspecies']
    AUTHOR_YEAR = ['author', 'year']

    LUMPS = {
      quadrinomial: QUAD,
      quad_author_year: QUAD + AUTHOR_YEAR,
      names:  Taxonifi::RANKS + AUTHOR_YEAR,
      higher: Taxonifi::RANKS - [QUAD + AUTHOR_YEAR],
      species: ['species', 'subspecies'],
      genera: ['genus', 'subgenus']
    }

    def self.available_lumps(columns)
      raise Taxonifi::Lumper::LumperError, 'Array not passed to Lumper.available_lumps.' if !(columns.class == Array)
      LUMPS.keys.select{|k| (LUMPS[k] - columns) == []}
    end

    #
    # TODO: Make this a generic parent/child indexer suitable for 
    # any heirachical data.  Should be straightforward- make collections
    # generic, and ensure that collection members respond_to id, parent etc.
    #  
    #  
    def self.create_name_collection(csv)
      raise Taxonifi::Lumper::LumperError, 'Something that is not a CSV::Table was passed to Lumper.create_name_collection.' if csv.class != CSV::Table
      nc = Taxonifi::Model::NameCollection.new

      row_size = csv.size

      # The row index contains a vector of parent ids like
      # [0, 4, 29]
      # This implies that Name with #id 29 has Parent with #id 4
      # Initialize an empty index. 
      row_index = []
      (0..(row_size-1)).each do |i|
        row_index[i] = []
      end

      # The name_index keeps track of unique name per rank like
      # :genus => {'Foo' => [0,2]}
      # This says that "Foo" is instantiated two times in the
      # name collection, with id 0, and id 2.
      name_index = {} 

      # First pass, create and index names
      Taxonifi::Assessor::RowAssessor.rank_headers(csv.headers).each do |rank|
        name_index[rank] = {}
        csv.each_with_index do |row, i|
          row_rank = Taxonifi::Assessor::RowAssessor.lump_rank(row).to_s # metadata (e.g. author year) apply to this rank 
          name = row[rank] 

          if !name.nil?     # cell has data
            n = nil         # a Name if necessary
            name_id = nil   # index the new or existing name 

            if name_index[rank][name] # name exists

              exists = false 
              name_index[rank][name].each do |id|
                # Compare vectors of parent_ids for name presence
                if nc.parent_id_vector(id) == row_index[i]      
                  exists = true
                  name_id = id
                  break # don't need to check further
                end 
              end

              if !exists # name (string) exists, but parents are different, create new name 
                n = Taxonifi::Model::Name.new()
              end

            else # no version of the name exists
              n = Taxonifi::Model::Name.new()
            end # end name exists

            # If we created a new name
            if !n.nil? 
              n.rank = rank
              n.name = name
              n.parent = nc.object_by_id(row_index[i].last) if row_index[i].size > 0 # it's parent is the previous id in this row 

              # Name/year needs to be standardized / cased out
              # headers are overlapping at times

              if row['author_year'] && row_rank == rank
                lexer = Taxonifi::Splitter::Lexer.new(row['author_year'])
                builder = Taxonifi::Model::AuthorYear.new
                Taxonifi::Splitter::Parser.new(lexer, builder).parse_author_year
                n.author               = builder.people 
                n.year                 = builder.year 
                n.original_combination = !builder.parens
              end

              name_id = nc.add_name(n) 
              # Add the name to the index of unique names
              name_index[rank][name] = [] if !name_index[rank][name] 
              name_index[rank][name].push name_id                
            end

            # build a by row vector of parent child relationships
            row_index[i].push name_id                       
          end # end cell has data

        end
      end

      nc
    end 


  end # end Lumper Module 
end # Taxonifi module
