meta :repo do
  def repo
    @repo ||= Babushka::GitRepo.new('.')
  end
end
