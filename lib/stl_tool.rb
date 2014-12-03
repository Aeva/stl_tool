require "matrix"


class STLParserError < StandardError; end




class Face
  def initialize(positions=nil, normals=nil)
    @positions = []
    @normals = []
    @special_normals = false

    if positions
      @positions = positions
    end

    if normals
      @normals = normals
      @special_normals = true
    end
  end


  def complete?
    return @positions.length == 3
  end


  def add_position(position)
    if @positions.length < 3
      @positions << position
    end
  end

  
  def to_s
    if @special_normals
      return "<face p=#{@positions} -- n=#{@normals}>"
    else
      return "<face p=#{@positions}>"
    end
  end


  def to_stl(type)
    if type == 'binary'
      return self.to_binary_stl
    elif type == 'ascii'
      return self.to_ascii_stl
    end
    
  end


  def to_binary_stl
    return ""
  end


  def to_ascii_stl
    return ""
  end


  def to_obj
    return ""
  end

end
    



class STLModel
  def initialize(stl_path, verbose_output=false)
    @file = File.open(stl_path, "rb")
    @path = stl_path
    header = @file.read(80)
    @file.rewind
    @faces = []
    @verbose = verbose_output

    if @verbose 
      puts "Parsing #{stl_path}..."
    end

    if header.start_with?("solid ")
      # the file is an ascii formatted stl
      process_ascii
    else
      # the file is a binary formatted stl
      process_binary
    end

    if @verbose
      puts "This file contains #{@faces.length} faces."
    end
  end

  def process_binary
    if @verbose
      puts "The file in question is a binary stl file."
    end
    header = @file.read(80).strip
    expecting = @file.read(4).unpack('L')[0] # uint32
    
    1.upto(expecting) do
      # 3x float32 (single precision) to create a single Vector
      normal = Vector.elements(@file.read(4*3).unpack('e3'))
      normals = [normal, normal, normal]
      # 9x float32 (single precision) to create three Vectors
      v_raw = @file.read(4*3*3).unpack('e9')
      vertices = [
                  Vector.elements(v_raw.slice(0,3)),
                  Vector.elements(v_raw.slice(3,3)),
                  Vector.elements(v_raw.slice(6,3)),
                 ]
      # uint16 unused in most implementations
      skip = @file.read(2)
      @faces << Face.new(vertices, normals)
    end
  end

  def process_ascii
    if @verbose
      puts "The file in question is an ascii stl file."
    end
    pending = nil
    @file.each.with_index do |line, line_num|
      # start building a new face in the model
      if line.strip.start_with?("facet")
        params = line.split(" ").each { |param| param.strip.downcase }
        if params.length == 5 and params[1] == "normal"
          normal = Vector.elements(params[2,3].map { |scalar| scalar.to_f })
          if normal.magnitude > 0
            normalized = normal.normalize
            pending = Face.new(normals=1.upto(3).map{normalized})
          end
        end
        if not pending
          pending = Face.new
        end
      end
      
      # add a vertex to the pending face
      if line.strip.start_with?("vertex") and pending
        params = line.split(" ").each { |param| param.strip.downcase }
        position = Vector.elements(params[1,3].map { |scalar| scalar.to_f })
        pending.add_position(position)
      end

      # add the pending face to our model
      if line.strip.start_with?("endfacet")
        if pending and pending.complete?
          @faces << pending
        else
          raise STLParserError, "Incompletel facet description at line "+
            "#{line_num} in file #{@path}."
        end
      end
    end
    if @verbose
      puts "Parsed #{@faces.length} triangles."
    end
  end

  private :process_binary
  private :process_ascii
end
