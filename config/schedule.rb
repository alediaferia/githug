every 2.days do
  rake "import:repos"
end

every 10.minutes do
  rake "classifier:run"
end
