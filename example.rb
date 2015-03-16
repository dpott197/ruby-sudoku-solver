@start_time = Time.now

require 'rglpk'

nums = [
[8,0,0,0,0,0,0,0,0],
[0,0,3,6,0,0,0,0,0],
[0,7,0,0,9,0,2,0,0],
[0,5,0,0,0,7,0,0,0],
[0,0,0,0,4,5,7,0,0],
[0,0,0,1,0,0,0,3,0],
[0,0,1,0,0,0,0,6,8],
[0,0,8,5,0,0,0,1,0],
[0,9,0,0,0,0,4,0,0],
].flatten

@perfect_square = Math.sqrt(nums.count).to_i
@givens = []
id = 0
@perfect_square.times do |row|
  @perfect_square.times do |col|
    unless nums[id]==0
      @givens << {
        row: row+1,
        col: col+1,
        num: nums[id],
      }
    end
    id += 1
  end
end

p = Rglpk::Problem.new
p.name = "Sudoku"
p.obj.dir = Rglpk::GLP_MAX

@rows = [*1..@perfect_square]
@cols = [*1..@perfect_square]
@nums = [*1..@perfect_square]
@subs = []

id = 1
root = Math.sqrt(@perfect_square).round
root.times do |r1|
  root.times do |r2|
    @subs << {
          id: id,
      row_lb: r1*root,
      col_lb: r2*root,
      row_ub: (r1+1)*root,
      col_ub: (r2+1)*root,
    }
    id += 1
  end
end

def sub(row,col)
  @subs.select{|sub|
    sub[:row_lb] <= row &&
    sub[:col_lb] <= col &&
    sub[:row_ub] >= row &&
    sub[:col_ub] >= col
    }.first[:id]
end

id = 0
@keys = []
@rows.each do |row|
  @cols.each do |col|
    @nums.each do |num|
      @keys << {
         id: id,
        row: row,
        col: col,
        num: num,
        sub: sub(row,col),
      }
      id += 1
    end
  end
end

cols = p.add_cols(@keys.count)
p.cols.each{|c| c.kind = Rglpk::GLP_BV}

@constraints = []
@bounds = []

@rows.each do |row| # Total Constraint
  @cols.each do |col|
    keys = @keys.select{|key|
      key[:row]==row and
      key[:col]==col
    }
    unless keys.nil?
      constraint = @keys.collect{0}
      keys.each{|key| constraint[key[:id]]=1}
      @constraints += constraint
    end
  end
end

@rows.each do |row| # Row Constraint
  @nums.each do |num|
    keys = @keys.select{|key|
      key[:row]==row and
      key[:num]==num
    }
    unless keys.nil?
      constraint = @keys.collect{0}
      keys.each{|key| constraint[key[:id]]=1}
      @constraints += constraint
    end
  end
end

@cols.each do |col| # Column Constraint
  @nums.each do |num|
    keys = @keys.select{|key|
      key[:col]==col and
      key[:num]==num
    }
    unless keys.nil?
      constraint = @keys.collect{0}
      keys.each{|key| constraint[key[:id]]=1}
      @constraints += constraint
    end
  end
end

@subs.each do |sub| # Sub-Region Constraint
  @nums.each do |num|
    keys = @keys.select{|key|
      key[:sub]==sub[:id] and
      key[:num]==num
    }
    unless keys.nil?
      constraint = @keys.collect{0}
      keys.each{|key| constraint[key[:id]]=1}
      @constraints += constraint
    end
  end
end

@givens.each do |given| # Given Constraint
  keys = @keys.select{|key|
    key[:row]==given[:row] and
    key[:col]==given[:col] and
    key[:num]==given[:num]
  }
  unless keys.nil?
    constraint = @keys.collect{0}
    keys.each{|key| constraint[key[:id]]=1}
    @constraints += constraint
  end
end

rows = p.add_rows(@constraints.count/@keys.count)
p.rows.each{|row| row.set_bounds(Rglpk::GLP_FX,1,0)}
p.set_matrix(@constraints)
p.obj.coefs = @keys.collect{1}
solution_method = :mip
value_method = :mip_val
p.simplex
p.send(solution_method, {:presolve => Rglpk::GLP_ON})
p.mip
z = p.obj.get
solutions = cols.collect.with_index{|x,i| [i,x.mip_val]}

# Print Sudoku
@rows.each do |row|
  xs = []
  @cols.each do |col|
    x = @keys.select{|x|
      x[:row]==row and
      x[:col]==col
    }.collect{|x|
      x[:num] if solutions[x[:id]][1]==1
    }.compact
    xs << x.first # Remove the 'first' to see all
  end
  p xs
end

@end_time = Time.now
@duration = (@end_time-@start_time)
p "Duration: #{@duration} sec(s)"