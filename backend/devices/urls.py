from django.urls import path
from .views import (
    DeviceListCreateView,
    DeviceDetailView,
)
from locations.views import (
    DeviceLocationView,
    DeviceLocationHistoryView,
)

urlpatterns = [
    path('', DeviceListCreateView.as_view(), name='device-list-create'),
    path('<int:pk>/', DeviceDetailView.as_view(), name='device-detail'),
    path('<int:pk>/location/', DeviceLocationView.as_view(), name='device-location'),
    path('<int:pk>/locations/', DeviceLocationHistoryView.as_view(), name='device-location-history'),
]
