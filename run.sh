./reinsall.sh
ndfx cHeaders
# Stop all dfx processes globally
dfx stop
# Stop project-specific dfx processes by visiting each project
for project_dir in /application/examples/*/; do
  if [ -f "$project_dir/dfx.json" ]; then
    echo "Stopping dfx in $project_dir"
    (cd "$project_dir" && dfx stop 2>/dev/null || true)
  fi
done
# Wait for processes to fully stop
sleep 2
# Clean all .dfx directories
find /application/examples -name ".dfx" -type d -exec rm -rf {} + 2>/dev/null || true
dfx start --clean --background --host 0.0.0.0:4943
