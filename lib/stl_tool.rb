require "matrix"


class STLParserError < StandardError; end


# take the cross product of two vec3s
def cross_product(lhs, rhs)
  cx = lhs[1] * rhs[2] - lhs[2] * rhs[1]
  cy = lhs[2] * rhs[0] - lhs[0] * rhs[2]
  cz = lhs[0] * rhs[1] - lhs[1] * rhs[0]
  return Vector.elements([cx, cy, cz])
end


class Face
  def initialize(positions=nil, normals=nil)
    @positions = []
    @normals = []
    @special_normals = false

    if positions
      @positions = positions
    end

    if normals
      a,b,c = normals
      if a.magnitude>0.0 && b.magnitude>0.0 && c.magnitude>0.0
        @normals = normals
        @special_normals = true
      end
    end
  end

  #
  # Returns true if this object has three vertices defined.
  #
  def complete?
    return @positions.length == 3
  end

  #
  # Return the face's vertex normals.
  #
  def normals
    if self.complete?
      if @normals.length == 3
        return @normals
      else
        a,b,c = @positions
        lhs = b-a
        rhs = c-a
        #normal = lhs.cross_product(rhs).normalize
        normal = cross_product(lhs, rhs)
        return [normal]*3
      end
    else
      return nil
    end
  end

  #
  # Returns the surface normal.
  #
  def single_normal
    normals = self.normals
    if normals != nil
      a,b,c = self.normals
      average = (a+b+c)/3
      return average.normalize
    else
      return nil
    end
  end

  #
  # Do some calculation per vertex.
  #
  def per_vertex
    if complete?
      i = 0
      for position in @positions do
        i+=1
        yield position
      end
    end
  end

  #
  # Add a vertex position to the face.
  #
  def add_position(position)
    if @positions.length < 3
      @positions << position
    end
  end
  
  #
  # Generic string representation.
  #
  def to_s
    if @special_normals
      return "<face p=#{@positions} -- n=#{@normals}>"
    else
      return "<face p=#{@positions}>"
    end
  end

  #
  # Transcode the face to STL
  #
  def to_stl(type)
    if type == 'binary'
      return self.to_binary_stl
    elif type == 'ascii'
      return self.to_ascii_stl
    end    
  end

  #
  # Transcode the face to binary formatted STL
  #
  def to_binary_stl
    output = "".b
    if self.complete?

      # Surface normal, as a tripple of Float32s 
      normal = self.single_normal
      if normal 
        output << normal.to_a.pack("e3")
      else
        output << [0,0,0].pack("e3")
      end

      # Each vertex position, as a tripple of Float32s
      a,b,c = @positions
      output << a.to_a.pack("e3")
      output << b.to_a.pack("e3")
      output << c.to_a.pack("e3")

      # Unused "attributes" uint16
      output << [0].pack("S")
    end
    return output
  end

  #
  # Transcode the face to ascii formatted STL
  #
  def to_ascii_stl
    return ""
  end

  #
  # Transcode the face to OBJ.
  #
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

  def per_face
    for face in @faces do
      yield face
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

  def output_ascii
    return "FIXME: ascii STL output."
  end

  def output_bin
    # write the STL header
    output = "Transcoded STL model via stl_tool.".b
    while output.length < 80 do
        output << "\0".b
    end

    # write the expected number of triangles
    output << [@faces.length].pack("L")

    # write out the triangle data
    for face in @faces do
      output << face.to_stl("binary")
    end
    return output
  end

  def output_obj
    return "FIXME: obj output."
  end

  private :process_binary
  private :process_ascii
end


def model_stats(model)
  minimums = [nil, nil, nil]
  maximums = [nil, nil, nil]
  average = nil
  count = 0
  model.per_face { |face|
    face.per_vertex { |position|
      0.upto(2) { |i|
        val = position[i]
        if minimums[i] == nil || val < minimums[i]
          minimums[i] = val
        end
        if maximums[i] == nil || val > maximums[i]
          maximums[i] = val
        end
        if average == nil
          average = position
        else
          average += position
        end
        count += 1
      }
    }
  }
  average /= count
  a_x = average[0].round(3)
  a_y = average[1].round(3)
  a_z = average[2].round(3)

  min_x = minimums[0].round(3)
  min_y = minimums[1].round(3)
  min_z = minimums[2].round(3)
  max_x = maximums[0].round(3)
  max_y = maximums[1].round(3)
  max_z = maximums[2].round(3)


  puts "Model statistics:"
  puts " - average: (#{a_x}, #{a_y}, #{a_z})"
  puts " - center: "
  puts " - min x: #{min_x}"
  puts " - min y: #{min_y}"
  puts " - min z: #{min_z}"
  puts " - max x: #{max_x}"
  puts " - max y: #{max_y}"
  puts " - max z: #{max_z}"
  puts count
end
