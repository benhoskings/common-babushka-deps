meta :git_hook do
  def ref_info
    git_ref_data.to_s.scan(
      # Form: <old_id> <new_id> refs/heads/<branch>?
      # e.g.: "83a90415670ec7ae4690d58563be628c73900716 e817f54d3e9a2d982b16328f8d7f0fbfcd7433f7 refs/heads/master"
      /\A([\da-f]{40}) ([\da-f]{40}) refs\/[^\/]+\/(.+)\z/
    ).flatten
  end

  def ref_info_piece position
    ref_info[position] || unmeetable!("Invalid git_ref_data '#{git_ref_data}'.")
  end

  def old_id; ref_info_piece(0) end
  def new_id; ref_info_piece(1) end
  def branch; ref_info_piece(2) end
end
