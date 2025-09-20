import { QueryClient } from '@tanstack/react-query';

// React Queryクライアントの設定
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 3,
      staleTime: 1000 * 60 * 5, // 5分
      gcTime: 1000 * 60 * 30, // 30分
    },
  },
});
