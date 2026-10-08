from django.urls import path
from .views import (
    DeviceListCreateView,
    DeviceDetailView,
    DeviceRingView,
    DeviceLostModeView,
)
from locations.views import (
    DeviceLocationView,
    DeviceLocationHistoryView,
)
from tracking.views import (
    DeviceStateView,
)

urlpatterns = [
    path('', DeviceListCreateView.as_view(), name='device-list-create'),
    path('<int:pk>/', DeviceDetailView.as_view(), name='device-detail'),
    path('<int:pk>/location/', DeviceLocationView.as_view(), name='device-location'),
    path('<int:pk>/locations/', DeviceLocationHistoryView.as_view(), name='device-location-history'),
    path('<int:pk>/state/', DeviceStateView.as_view(), name='device-state'),
    path('<int:pk>/ring/', DeviceRingView.as_view(), name='device-ring'),
    path('<int:pk>/lost-mode/', DeviceLostModeView.as_view(), name='device-lost-mode'),
]
